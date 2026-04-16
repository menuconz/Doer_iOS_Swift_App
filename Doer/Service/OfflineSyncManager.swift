import Foundation
import Network
import BackgroundTasks

actor OfflineSyncManager {
    static let shared = OfflineSyncManager()

    private let trackingRepo = DIContainer.shared.trackingRepository
    private let prefs = DIContainer.shared.preferencesManager

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let clockEventsFile: URL
    private let locationPointsFile: URL
    private let notificationsFile: URL

    private let pathMonitor = NWPathMonitor()
    private var isOnline = true

    private static let maxSyncAttempts = 5

    private init() {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OfflineSync", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        clockEventsFile = dir.appendingPathComponent("pending_clock_events.json")
        locationPointsFile = dir.appendingPathComponent("pending_location_points.json")
        notificationsFile = dir.appendingPathComponent("pending_notifications.json")

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let online = path.status == .satisfied
            Task { await self.onNetworkChanged(online) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "nz.co.doer.network"))
    }

    private var retryCount = 0
    private static let maxRetries = 5
    private static let baseRetryInterval: TimeInterval = 30 // 30 seconds

    private func onNetworkChanged(_ online: Bool) {
        let wasOffline = !isOnline
        isOnline = online
        if online && wasOffline {
            retryCount = 0
            Task { await syncWithBackoff() }
        } else if !online {
            scheduleBackgroundSync()
        }
    }

    private func syncWithBackoff() async {
        let success = await syncAll()
        if !success && retryCount < Self.maxRetries {
            retryCount += 1
            let delay = Self.baseRetryInterval * pow(2.0, Double(retryCount - 1))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if isOnline {
                await syncWithBackoff()
            }
        } else {
            retryCount = 0
        }
    }

    // MARK: - Queue Events

    func queueClockEvent(
        userId: String, shiftId: Int, eventType: String, locationType: Int,
        trackingState: Int, latitude: Double, longitude: Double,
        timestamp: String, reasonCode: String? = nil,
        subItemId: Int? = nil, subItemName: String? = nil
    ) async {
        let event = PendingClockEvent(
            userId: userId, shiftId: shiftId, eventType: eventType,
            locationType: locationType, trackingState: trackingState,
            latitude: latitude, longitude: longitude, timestamp: timestamp,
            reasonCode: reasonCode,
            subItemId: subItemId, subItemName: subItemName
        )
        var events = loadClockEvents()
        events.append(event)
        saveClockEvents(events)

        if isOnline {
            await syncClockEvents()
        }
    }

    func queueLocationPoints(userId: String, shiftId: Int, points: [LocationPointDto]) async {
        let pending = points.map {
            PendingLocationPoint(
                userId: userId, shiftId: shiftId,
                latitude: $0.latitude, longitude: $0.longitude,
                timestamp: $0.timestamp, accuracy: $0.accuracy,
                speed: $0.speed, bearing: $0.bearing
            )
        }
        var existing = loadLocationPoints()
        existing.append(contentsOf: pending)
        saveLocationPoints(existing)

        if isOnline {
            await syncLocationPoints()
        }
    }

    func queueNotification(
        userId: String, shiftId: Int, notificationType: String,
        title: String, body: String, trackingState: Int,
        latitude: Double, longitude: Double, timestamp: String,
        hoursOnSite: Double? = nil
    ) async {
        let notif = PendingNotification(
            userId: userId, shiftId: shiftId, notificationType: notificationType,
            title: title, body: body, trackingState: trackingState,
            latitude: latitude, longitude: longitude, timestamp: timestamp,
            hoursOnSite: hoursOnSite
        )
        var existing = loadNotifications()
        existing.append(notif)
        saveNotifications(existing)

        if isOnline {
            await syncNotifications()
        }
    }

    // MARK: - Sync All

    @discardableResult
    func syncAll() async -> Bool {
        var allSuccess = true
        if !(await syncClockEvents()) { allSuccess = false }
        if !(await syncLocationPoints()) { allSuccess = false }
        if !(await syncNotifications()) { allSuccess = false }
        cleanupOldSynced()
        return allSuccess
    }

    // MARK: - Sync Clock Events

    private func syncClockEvents() async -> Bool {
        var events = loadClockEvents()
        let unsynced = events.filter { !$0.synced && $0.syncAttempts < Self.maxSyncAttempts }
        guard !unsynced.isEmpty else { return true }

        var allSuccess = true
        let authUid = prefs.basicAuthUid

        for event in unsynced {
            let dto = ClockEventDto(
                userId: event.userId, shiftId: event.shiftId,
                eventType: event.eventType, locationType: event.locationType,
                trackingState: event.trackingState,
                latitude: event.latitude, longitude: event.longitude,
                timestamp: event.timestamp, reasonCode: event.reasonCode,
                isOffline: true,
                subItemId: event.subItemId, subItemName: event.subItemName,
                lId: Constants.lId, siteId: Constants.siteId, basicAuthUid: authUid
            )

            switch await trackingRepo.recordClockEvent(dto) {
            case .success:
                if let i = events.firstIndex(where: { $0.id == event.id }) {
                    events[i].synced = true
                }
            case .error:
                if let i = events.firstIndex(where: { $0.id == event.id }) {
                    events[i].syncAttempts += 1
                }
                allSuccess = false
            case .loading: break
            }
        }
        saveClockEvents(events)
        return allSuccess
    }

    // MARK: - Sync Location Points

    private func syncLocationPoints() async -> Bool {
        var points = loadLocationPoints()
        let unsynced = points.filter { !$0.synced }
        guard !unsynced.isEmpty else { return true }

        let authUid = prefs.basicAuthUid
        let userId = prefs.userId
        var allSuccess = true

        // Group by shiftId and batch in groups of 10
        let grouped = Dictionary(grouping: unsynced) { $0.shiftId }
        for (shiftId, shiftPoints) in grouped {
            for batch in shiftPoints.chunked(into: 10) {
                let dto = LocationBatchDto(
                    userId: userId, shiftId: shiftId,
                    points: batch.map {
                        LocationPointDto(latitude: $0.latitude, longitude: $0.longitude,
                                         timestamp: $0.timestamp, accuracy: $0.accuracy,
                                         speed: $0.speed, bearing: $0.bearing)
                    },
                    lId: Constants.lId, siteId: Constants.siteId, basicAuthUid: authUid
                )
                switch await trackingRepo.sendLocationBatch(dto) {
                case .success:
                    let ids = Set(batch.map { $0.id })
                    for i in points.indices where ids.contains(points[i].id) {
                        points[i].synced = true
                    }
                case .error:
                    allSuccess = false
                case .loading: break
                }
            }
        }
        saveLocationPoints(points)
        return allSuccess
    }

    // MARK: - Sync Notifications

    private func syncNotifications() async -> Bool {
        var notifications = loadNotifications()
        let unsynced = notifications.filter { !$0.synced && $0.syncAttempts < Self.maxSyncAttempts }
        guard !unsynced.isEmpty else { return true }

        let authUid = prefs.basicAuthUid
        var allSuccess = true

        for notif in unsynced {
            let dto = TrackingNotificationDto(
                userId: notif.userId, shiftId: notif.shiftId,
                notificationType: notif.notificationType,
                title: notif.title, body: notif.body,
                trackingState: notif.trackingState,
                latitude: notif.latitude, longitude: notif.longitude,
                timestamp: notif.timestamp, hoursOnSite: notif.hoursOnSite,
                lId: Constants.lId, siteId: Constants.siteId, basicAuthUid: authUid
            )
            switch await trackingRepo.sendTrackingNotification(dto) {
            case .success:
                if let i = notifications.firstIndex(where: { $0.id == notif.id }) {
                    notifications[i].synced = true
                }
            case .error:
                if let i = notifications.firstIndex(where: { $0.id == notif.id }) {
                    notifications[i].syncAttempts += 1
                }
                allSuccess = false
            case .loading: break
            }
        }
        saveNotifications(notifications)
        return allSuccess
    }

    // MARK: - Cleanup

    private func cleanupOldSynced() {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)

        var events = loadClockEvents()
        events.removeAll { $0.synced && $0.createdAt < cutoff }
        saveClockEvents(events)

        var points = loadLocationPoints()
        points.removeAll { $0.synced && $0.createdAt < cutoff }
        saveLocationPoints(points)

        var notifs = loadNotifications()
        notifs.removeAll { $0.synced && $0.createdAt < cutoff }
        saveNotifications(notifs)
    }

    // MARK: - Background Task Scheduling (survives app suspend)

    static let bgTaskIdentifier = "nz.co.doer.trackingsync"

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskIdentifier, using: nil) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            Task {
                let success = await OfflineSyncManager.shared.syncAll()
                bgTask.setTaskCompleted(success: success)
            }
            bgTask.expirationHandler = {
                bgTask.setTaskCompleted(success: false)
            }
        }
    }

    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: Self.bgTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    func getPendingCount() -> Int {
        loadClockEvents().filter { !$0.synced }.count +
        loadLocationPoints().filter { !$0.synced }.count +
        loadNotifications().filter { !$0.synced }.count
    }

    // MARK: - File I/O

    private func loadClockEvents() -> [PendingClockEvent] {
        load(from: clockEventsFile) ?? []
    }
    private func saveClockEvents(_ events: [PendingClockEvent]) {
        save(events, to: clockEventsFile)
    }
    private func loadLocationPoints() -> [PendingLocationPoint] {
        load(from: locationPointsFile) ?? []
    }
    private func saveLocationPoints(_ points: [PendingLocationPoint]) {
        save(points, to: locationPointsFile)
    }
    private func loadNotifications() -> [PendingNotification] {
        load(from: notificationsFile) ?? []
    }
    private func saveNotifications(_ notifs: [PendingNotification]) {
        save(notifs, to: notificationsFile)
    }

    private func load<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Pending Entities

struct PendingClockEvent: Codable, Identifiable {
    let id: UUID
    let userId: String
    let shiftId: Int
    let eventType: String
    let locationType: Int
    let trackingState: Int
    let latitude: Double
    let longitude: Double
    let timestamp: String
    let reasonCode: String?
    let subItemId: Int?
    let subItemName: String?
    let createdAt: Date
    var synced: Bool
    var syncAttempts: Int

    init(userId: String, shiftId: Int, eventType: String, locationType: Int,
         trackingState: Int, latitude: Double, longitude: Double,
         timestamp: String, reasonCode: String?,
         subItemId: Int? = nil, subItemName: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.shiftId = shiftId
        self.eventType = eventType
        self.locationType = locationType
        self.trackingState = trackingState
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.reasonCode = reasonCode
        self.subItemId = subItemId
        self.subItemName = subItemName
        self.createdAt = Date()
        self.synced = false
        self.syncAttempts = 0
    }
}

struct PendingLocationPoint: Codable, Identifiable {
    let id: UUID
    let userId: String
    let shiftId: Int
    let latitude: Double
    let longitude: Double
    let timestamp: String
    let accuracy: Float
    let speed: Float
    let bearing: Float
    let createdAt: Date
    var synced: Bool

    init(userId: String, shiftId: Int, latitude: Double, longitude: Double,
         timestamp: String, accuracy: Float, speed: Float, bearing: Float) {
        self.id = UUID()
        self.userId = userId
        self.shiftId = shiftId
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.accuracy = accuracy
        self.speed = speed
        self.bearing = bearing
        self.createdAt = Date()
        self.synced = false
    }
}

struct PendingNotification: Codable, Identifiable {
    let id: UUID
    let userId: String
    let shiftId: Int
    let notificationType: String
    let title: String
    let body: String
    let trackingState: Int
    let latitude: Double
    let longitude: Double
    let timestamp: String
    let hoursOnSite: Double?
    let createdAt: Date
    var synced: Bool
    var syncAttempts: Int

    init(userId: String, shiftId: Int, notificationType: String,
         title: String, body: String, trackingState: Int,
         latitude: Double, longitude: Double, timestamp: String,
         hoursOnSite: Double?) {
        self.id = UUID()
        self.userId = userId
        self.shiftId = shiftId
        self.notificationType = notificationType
        self.title = title
        self.body = body
        self.trackingState = trackingState
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.hoursOnSite = hoursOnSite
        self.createdAt = Date()
        self.synced = false
        self.syncAttempts = 0
    }
}

