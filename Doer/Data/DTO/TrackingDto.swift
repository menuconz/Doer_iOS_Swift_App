import Foundation

// MARK: - Tracking State Machine
enum DoerTrackingState: Int, Codable {
    case idle = 0
    case clockedIn = 1
    case enRoute = 2
    case arrived = 3
    case onSite = 4
    case leaving = 5
    case clockedOut = 6

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .clockedIn: return "Clocked In"
        case .enRoute: return "On the Way"
        case .arrived: return "Arrived"
        case .onSite: return "On Site"
        case .leaving: return "Leaving"
        case .clockedOut: return "Clocked Out"
        }
    }

    static func validTransitions(from current: DoerTrackingState) -> Set<DoerTrackingState> {
        switch current {
        case .idle: return [.clockedIn]
        case .clockedIn: return [.enRoute, .onSite, .clockedOut]
        case .enRoute: return [.arrived, .clockedOut]
        case .arrived: return [.onSite, .leaving, .clockedOut] // LEAVING if user exits before DWELL confirms
        case .onSite: return [.leaving, .clockedOut]
        case .leaving: return [.onSite, .clockedOut]
        case .clockedOut: return [.clockedIn]
        }
    }
}

enum ClockLocationType: Int, Codable {
    case site = 1
    case yard = 2
    case office = 3
}

enum ClockEventType: String, Codable {
    case clockIn = "CLOCK_IN"
    case clockOut = "CLOCK_OUT"
    case locationUpdate = "LOCATION_UPDATE"
    case geofenceEnter = "GEOFENCE_ENTER"
    case geofenceExit = "GEOFENCE_EXIT"
    case stateChange = "STATE_CHANGE"
}

// MARK: - Clock Event DTO
struct ClockEventDto: Codable {
    var id: Int = 0
    var userId: String = ""
    var shiftId: Int = 0
    var eventType: String = ""
    var locationType: Int = 1
    var trackingState: Int = 0
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var timestamp: String = ""
    var reasonCode: String?
    var isOffline: Bool = false
    var subItemId: Int?
    var subItemName: String?
    var lId: Int = 0
    var siteId: Int = 1
    var contactID: Int = 0
    var errorMessage: String?
    var basicAuthUid: String = ""
}

// MARK: - Location Batch DTO
struct LocationBatchDto: Codable {
    var userId: String = ""
    var shiftId: Int = 0
    var points: [LocationPointDto] = []
    var lId: Int = 0
    var siteId: Int = 1
    var basicAuthUid: String = ""
}

struct LocationPointDto: Codable {
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var timestamp: String = ""
    var accuracy: Float = 0
    var speed: Float = 0
    var bearing: Float = 0
}

// MARK: - Tracking Status DTO
struct TrackingStatusDto: Codable {
    var userId: String = ""
    var shiftId: Int = 0
    var trackingState: Int = 0
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var timestamp: String = ""
    var eta: String?
    var distanceRemaining: Double?
    var displayName: String = ""
    var projectName: String = ""
    var siteName: String = ""
    var siteLatitude: Double?
    var siteLongitude: Double?
    var lId: Int = 0
    var siteId: Int = 1
    var basicAuthUid: String = ""
}

// MARK: - Tracking Notification DTO
struct TrackingNotificationDto: Codable {
    var userId: String = ""
    var shiftId: Int = 0
    var notificationType: String = ""
    var title: String = ""
    var body: String = ""
    var trackingState: Int = 0
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var timestamp: String = ""
    var hoursOnSite: Double?
    var lId: Int = 0
    var siteId: Int = 1
    var basicAuthUid: String = ""
}

// MARK: - Edit Time Entry DTO
struct EditTimeEntryDto: Codable {
    var userId: String = ""
    var shiftId: Int = 0
    var clockInTime: String?
    var clockOutTime: String?
    var reasonCode: String = ""
    var editedBy: String = ""
    var lId: Int = 0
    var siteId: Int = 1
    var basicAuthUid: String = ""
}
