import Foundation

struct SiteHoursSummaryDto: Codable {
    var shiftId: Int = 0
    var projectName: String = ""
    var address: String = ""
    var clientName: String?
    var totalHours: Double = 0.0
    var doerCount: Int = 0
    var stages: [StageHoursDto] = []
    var doerHours: [DoerHoursDto] = []
}

struct DoerHoursDto: Codable {
    var userId: String = ""
    var displayName: String = ""
    var shiftId: Int = 0
    var clockInTime: String?
    var clockOutTime: String?
    var totalHours: Double = 0.0
    var stage: String = ""
    var isActive: Bool = false
    var sessions: [SessionDto] = []
}

struct SessionDto: Codable {
    var date: String = ""
    var clockInTime: String = ""
    var clockOutTime: String?
    var hours: Double = 0.0
    var stage: String = ""
    var isActive: Bool = false
}

struct StageHoursDto: Codable {
    var stageName: String = ""
    var totalHours: Double = 0.0
    var doerCount: Int = 0
}

struct TimeTrackingFilterDto: Codable {
    var date: String?
    var dateFrom: String?
    var dateTo: String?
    var userId: String = ""
    var lId: Int = 0
    var siteId: Int = 1
    var basicAuthUid: String = ""
}
