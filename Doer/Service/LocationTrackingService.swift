import Foundation
import CoreLocation

enum TrackingMode {
    case enRoute  // High frequency: best accuracy, 50m distance filter
    case onSite   // Low frequency: 100m distance filter
}

class LocationTrackingService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingService()

    private let locationManager = CLLocationManager()
    private let trackingManager = TrackingManager.shared
    private var isTracking = false
    private var currentMode: TrackingMode = .enRoute
    // Mode requested while permission was still being decided — applied once granted.
    private var pendingStartMode: TrackingMode?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }

    func startTracking(mode: TrackingMode = .enRoute) {
        guard !isTracking else {
            updateMode(mode)
            return
        }

        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            // The permission prompt is async — remember the requested mode and let
            // locationManagerDidChangeAuthorization kick off tracking once granted.
            pendingStartMode = mode
            locationManager.requestAlwaysAuthorization()
            return
        }
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            print("LocationTrackingService: No location permission")
            return
        }

        currentMode = mode
        applyMode(mode)
        locationManager.startUpdatingLocation()
        isTracking = true
        print("LocationTrackingService: Started (\(mode))")
    }

    func stopTracking() {
        guard isTracking else { return }
        locationManager.stopUpdatingLocation()
        isTracking = false
        trackingManager.flushLocationBatch()
        print("LocationTrackingService: Stopped")
    }

    func updateMode(_ mode: TrackingMode) {
        guard currentMode != mode else { return }
        currentMode = mode
        applyMode(mode)
        print("LocationTrackingService: Mode updated to \(mode)")
    }

    private func applyMode(_ mode: TrackingMode) {
        switch mode {
        case .enRoute:
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 50 // 50 meters
            locationManager.activityType = .automotiveNavigation // Wait for accurate location
        case .onSite:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 100 // 100 meters
            locationManager.activityType = .other
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let point = LocationPointDto(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Constants.nowNz(),
            accuracy: Float(location.horizontalAccuracy),
            speed: Float(max(0, location.speed)),
            bearing: Float(max(0, location.course))
        )
        trackingManager.addLocationPoint(point)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationTrackingService error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            if isTracking, let shiftId = trackingManager.activeShiftId {
                TrackingNotificationHelper.shared.onGpsPermissionRevoked(shiftId: shiftId)
            }
            pendingStartMode = nil
            return
        }
        // If a start was queued while the user was deciding, fire it now.
        if (status == .authorizedAlways || status == .authorizedWhenInUse),
           let mode = pendingStartMode, !isTracking {
            pendingStartMode = nil
            startTracking(mode: mode)
        }
    }
}
