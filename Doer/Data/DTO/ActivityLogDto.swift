import Foundation

struct ActivityLogDto: Codable, Identifiable, Hashable {
    var id: Int = 0
    var userId: String = ""
    var userName: String = ""
    var entityType: String = ""
    var entityId: Int = 0
    var action: String = ""
    var fieldName: String? = nil
    var oldValue: String? = nil
    var newValue: String? = nil
    var description: String? = nil
    var ipAddress: String? = nil
    var timestamp: String = ""
}

struct ActivityLogPagedDto: Codable {
    var totalCount: Int = 0
    var logs: [ActivityLogDto] = []
}
