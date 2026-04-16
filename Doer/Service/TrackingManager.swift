import Foundation
import CoreLocation
import Combine

class TrackingManager: ObservableObject {
    static let shared = TrackingManager()

    @Published var trackingState: DoerTrackingState = .idle
    @Published var activeShiftId: Int?
    @Published var clockLocationType: ClockLocationType = .site

    private let geofenceManager = GeofenceManager.shared
    private let notificationHelper = TrackingNotificationHelper.shared
    private let trackingRepo = DIContainer.shared.trackingRepository
    private let prefs = DIContainer.shared.preferencesManager
    private let offlineSync = OfflineSyncManager.shared

    private var locationBatch: [LocationPointDto] = []
    private let batchLock = NSLock()

    // Grace period
    private var graceTimer: Timer?
    static let gracePeriodSeconds: TimeInterval = 5 * 60 // 5 minutes

    // 12-hour threshold
    private var thresholdTimer: Timer?
    private var onSiteStartTime: Date?
    private var warningFired = false
    private var exceededFired = false
    static let thresholdHours: Double = 12.0
    static let warningHours: Double = 11.0

    var activeProjectName: String = ""
    static let geofenceExpirationHours: TimeInterval = 12 * 60 * 60
    private var geofenceExpirationTimer: Timer?

    // Last known location + active site — used for status pushes between GPS samples
    private var lastKnownLat: Double = 0.0
    private var lastKnownLng: Double = 0.0
    private var activeSiteLat: Double?
    private var activeSiteLng: Double?

    // Selected sub-item / stage for the active shift (for per-stage hours reporting)
    private var activeSubItemId: Int?
    private var activeSubItemName: String?

    static func distanceBetween(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Float {
        Float(CLLocation(latitude: lat1, longitude: lng1).distance(from: CLLocation(latitude: lat2, longitude: lng2)))
    }

    private init() {
        geofenceManager.onGeofenceEnter = { [weak self] shiftId, lat, lng in
            self?.onGeofenceEnter(shiftId: shiftId, latitude: lat, longitude: lng)
        }
        geofenceManager.onGeofenceExit = { [weak self] shiftId, lat, lng in
            self?.onGeofenceExit(shiftId: shiftId, latitude: lat, longitude: lng)
        }
    }

    // MARK: - Clock In

    func clockIn(shiftId: Int, locationType: ClockLocationType,
                 siteLatitude: Double?, siteLongitude: Double?,
                 currentLatitude: Double, currentLongitude: Double,
                 projectName: String = "",
                 subItemId: Int? = nil, subItemName: String? = nil) {
        // Stage session state before transition so status pushes have context
        activeShiftId = shiftId
        clockLocationType = locationType
        activeProjectName = projectName
        activeSiteLat = siteLatitude
        activeSiteLng = siteLongitude
        activeSubItemId = (subItemId == 0) ? nil : subItemId
        activeSubItemName = (subItemName?.isEmpty == true) ? nil : subItemName
        updateLastKnownLocation(latitude: currentLatitude, longitude: currentLongitude)

        guard transitionTo(.clockedIn) else { return }
        // Note: do NOT push status here — we'll transition immediately to .enRoute or
        // .onSite below and push the FINAL state once. Pushing twice in quick succession
        // races on the server and can leave Live Tracking stuck on "Clocked In".

        recordClockEvent(shiftId: shiftId, eventType: .clockIn,
                         latitude: currentLatitude, longitude: currentLongitude)

        notificationHelper.onClockIn(shiftId: shiftId, latitude: currentLatitude,
                                      longitude: currentLongitude, projectName: projectName)

        // Register geofence at the shift's location regardless of Site/Yard/Office —
        // the shift's coordinates are always the destination the worker is travelling to.
        if let siteLat = siteLatitude, let siteLng = siteLongitude,
           siteLat != 0, siteLng != 0 {
            geofenceManager.registerSiteGeofence(shiftId: shiftId, latitude: siteLat, longitude: siteLng)
            startGeofenceExpirationTimer(shiftId: shiftId)

            let distance = CLLocation(latitude: currentLatitude, longitude: currentLongitude)
                .distance(from: CLLocation(latitude: siteLat, longitude: siteLng))

            if distance <= GeofenceManager.defaultRadius {
                _ = transitionTo(.onSite)
                pushTrackingStatus()
                startOnSiteMonitoring()
                LocationTrackingService.shared.startTracking(mode: .onSite)
            } else {
                _ = transitionTo(.enRoute)
                pushTrackingStatus()
                notificationHelper.onEnRoute(shiftId: shiftId, latitude: currentLatitude,
                                              longitude: currentLongitude, projectName: projectName)
                LocationTrackingService.shared.startTracking(mode: .enRoute)
            }
        } else {
            // No coordinates available on the shift — fall through to ON_SITE directly.
            _ = transitionTo(.onSite)
            pushTrackingStatus()
            startOnSiteMonitoring()
            LocationTrackingService.shared.startTracking(mode: .onSite)
        }
    }

    // MARK: - Clock Out

    func clockOut(currentLatitude: Double = 0, currentLongitude: Double = 0, reasonCode: String? = nil) {
        guard let shiftId = activeShiftId else { return }

        if currentLatitude != 0 || currentLongitude != 0 {
            updateLastKnownLocation(latitude: currentLatitude, longitude: currentLongitude)
        }

        _ = transitionTo(.clockedOut)
        pushTrackingStatus()

        stopOnSiteMonitoring()
        cancelGraceTimer()

        recordClockEvent(shiftId: shiftId, eventType: .clockOut,
                         latitude: currentLatitude, longitude: currentLongitude, reasonCode: reasonCode)

        notificationHelper.onClockOut(shiftId: shiftId, latitude: currentLatitude,
                                       longitude: currentLongitude, projectName: activeProjectName)

        flushLocationBatch()
        geofenceManager.removeGeofence(shiftId: shiftId)
        LocationTrackingService.shared.stopTracking()

        activeShiftId = nil
        activeProjectName = ""
        activeSiteLat = nil
        activeSiteLng = nil
        activeSubItemId = nil
        activeSubItemName = nil
        trackingState = .idle
    }

    // MARK: - Geofence Events

    func onGeofenceEnter(shiftId: Int, latitude: Double, longitude: Double) {
        guard activeShiftId == shiftId else { return }
        updateLastKnownLocation(latitude: latitude, longitude: longitude)

        if trackingState == .enRoute {
            _ = transitionTo(.arrived)
            pushTrackingStatus()
            recordClockEvent(shiftId: shiftId, eventType: .geofenceEnter, latitude: latitude, longitude: longitude)
            notificationHelper.onArrived(shiftId: shiftId, latitude: latitude, longitude: longitude, projectName: activeProjectName)
            LocationTrackingService.shared.updateMode(.onSite)

            // After dwell delay, confirm ON_SITE
            DispatchQueue.main.asyncAfter(deadline: .now() + GeofenceManager.dwellDelay) { [weak self] in
                if self?.trackingState == .arrived {
                    _ = self?.transitionTo(.onSite)
                    self?.pushTrackingStatus()
                    self?.startOnSiteMonitoring()
                }
            }
        } else if trackingState == .leaving {
            _ = transitionTo(.onSite)
            pushTrackingStatus()
            cancelGraceTimer()
        }
    }

    func onGeofenceExit(shiftId: Int, latitude: Double, longitude: Double) {
        guard activeShiftId == shiftId else { return }
        updateLastKnownLocation(latitude: latitude, longitude: longitude)

        if trackingState == .onSite || trackingState == .arrived {
            _ = transitionTo(.leaving)
            pushTrackingStatus()
            recordClockEvent(shiftId: shiftId, eventType: .geofenceExit, latitude: latitude, longitude: longitude)
            notificationHelper.onLeftSite(shiftId: shiftId, latitude: latitude, longitude: longitude, projectName: activeProjectName)
            startGraceTimer()
        }
    }

    // MARK: - Grace Period

    private func startGraceTimer() {
        cancelGraceTimer()
        graceTimer = Timer.scheduledTimer(withTimeInterval: TrackingManager.gracePeriodSeconds, repeats: false) { [weak self] _ in
            if self?.trackingState == .leaving {
                self?.clockOut()
            }
        }
    }

    private func cancelGraceTimer() {
        graceTimer?.invalidate()
        graceTimer = nil
    }

    // MARK: - 12-Hour Threshold

    private func startOnSiteMonitoring() {
        onSiteStartTime = Date()
        warningFired = false
        exceededFired = false

        thresholdTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            self?.checkThreshold()
        }
    }

    private func stopOnSiteMonitoring() {
        thresholdTimer?.invalidate()
        thresholdTimer = nil
        onSiteStartTime = nil
    }

    private func checkThreshold() {
        guard let start = onSiteStartTime, let shiftId = activeShiftId else { return }
        let hours = Date().timeIntervalSince(start) / 3600.0

        if hours >= TrackingManager.warningHours && !warningFired {
            warningFired = true
            notificationHelper.onThresholdWarning(shiftId: shiftId, hoursOnSite: hours, projectName: activeProjectName)
        }
        if hours >= TrackingManager.thresholdHours && !exceededFired {
            exceededFired = true
            notificationHelper.onThresholdExceeded(shiftId: shiftId, hoursOnSite: hours, projectName: activeProjectName)
        }
    }

    func getHoursOnSite() -> Double {
        guard let start = onSiteStartTime else { return 0 }
        return Date().timeIntervalSince(start) / 3600.0
    }

    // MARK: - Location Batching

    func addLocationPoint(_ point: LocationPointDto) {
        updateLastKnownLocation(latitude: point.latitude, longitude: point.longitude)
        batchLock.lock()
        locationBatch.append(point)
        if locationBatch.count >= 5 {
            let points = locationBatch
            locationBatch.removeAll()
            batchLock.unlock()
            sendBatch(points)
        } else {
            batchLock.unlock()
        }
    }

    private func updateLastKnownLocation(latitude: Double, longitude: Double) {
        if latitude == 0 && longitude == 0 { return }
        lastKnownLat = latitude
        lastKnownLng = longitude
    }

    /// Pushes a snapshot of the current tracking state to the server so the manager
    /// live-map reflects state transitions in near real time. Called after every state change.
    private func pushTrackingStatus() {
        guard let shiftId = activeShiftId else { return }
        let state = trackingState
        let siteLat = activeSiteLat
        let siteLng = activeSiteLng
        let lat = lastKnownLat
        let lng = lastKnownLng

        var distanceRemaining: Double? = nil
        if state == .enRoute, let sLat = siteLat, let sLng = siteLng, lat != 0, lng != 0 {
            distanceRemaining = Double(TrackingManager.distanceBetween(lat, lng, sLat, sLng))
        }

        let dto = TrackingStatusDto(
            userId: prefs.userId,
            shiftId: shiftId,
            trackingState: state.rawValue,
            latitude: lat,
            longitude: lng,
            timestamp: Constants.nowNz(),
            eta: nil,
            distanceRemaining: distanceRemaining,
            displayName: "",
            projectName: "",
            siteName: "",
            siteLatitude: siteLat,
            siteLongitude: siteLng,
            lId: 0,
            siteId: 1,
            basicAuthUid: prefs.basicAuthUid
        )

        Task {
            _ = await trackingRepo.updateTrackingStatus(dto)
            print("TrackingManager: Pushed status state=\(state), shiftId=\(shiftId)")
        }
    }

    func flushLocationBatch() {
        batchLock.lock()
        let points = locationBatch
        locationBatch.removeAll()
        batchLock.unlock()
        if !points.isEmpty { sendBatch(points) }
    }

    private func sendBatch(_ points: [LocationPointDto]) {
        guard let shiftId = activeShiftId else { return }
        let userId = prefs.userId
        Task {
            await offlineSync.queueLocationPoints(userId: userId, shiftId: shiftId, points: points)
        }
    }

    // MARK: - State Machine

    private func transitionTo(_ newState: DoerTrackingState) -> Bool {
        let valid = DoerTrackingState.validTransitions(from: trackingState)
        guard valid.contains(newState) else {
            print("TrackingManager: Invalid transition \(trackingState) → \(newState)")
            return false
        }
        print("TrackingManager: \(trackingState) → \(newState)")
        DispatchQueue.main.async { self.trackingState = newState }
        return true
    }

    // MARK: - Geofence Expiration (12 hours auto-remove)

    private func startGeofenceExpirationTimer(shiftId: Int) {
        geofenceExpirationTimer?.invalidate()
        geofenceExpirationTimer = Timer.scheduledTimer(withTimeInterval: TrackingManager.geofenceExpirationHours, repeats: false) { [weak self] _ in
            self?.geofenceManager.removeGeofence(shiftId: shiftId)
            print("TrackingManager: Geofence expired after 12 hours for shift \(shiftId)")
        }
    }

    // MARK: - Auto Clock-In Suggestion

    func checkAutoClockInSuggestion(shiftId: Int, projectName: String) {
        guard trackingState == .idle, activeShiftId == nil else { return }
        notificationHelper.onAutoClockInSuggestion(shiftId: shiftId, projectName: projectName)
    }

    private func recordClockEvent(shiftId: Int, eventType: ClockEventType,
                                   latitude: Double, longitude: Double, reasonCode: String? = nil) {
        let userId = prefs.userId
        let locType = clockLocationType.rawValue
        let state = trackingState.rawValue
        let ts = Constants.nowNz()
        let subId = activeSubItemId
        let subName = activeSubItemName
        Task {
            await offlineSync.queueClockEvent(
                userId: userId, shiftId: shiftId, eventType: eventType.rawValue,
                locationType: locType, trackingState: state,
                latitude: latitude, longitude: longitude,
                timestamp: ts, reasonCode: reasonCode,
                subItemId: subId, subItemName: subName
            )
        }
    }
}
