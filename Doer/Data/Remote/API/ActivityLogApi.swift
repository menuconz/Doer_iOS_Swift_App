import Foundation
import Alamofire

class ActivityLogApi {
    private let network = NetworkManager.shared

    func getLogs(
        entityType: String? = nil,
        entityId: Int? = nil,
        userId: String? = nil,
        action: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        skip: Int = 0,
        take: Int = 50
    ) async throws -> ActivityLogPagedDto {
        var params: [String: Any] = ["skip": skip, "take": take]
        if let v = entityType, !v.isEmpty { params["entityType"] = v }
        if let v = entityId { params["entityId"] = v }
        if let v = userId, !v.isEmpty { params["userId"] = v }
        if let v = action, !v.isEmpty { params["action"] = v }
        if let v = startDate, !v.isEmpty { params["startDate"] = v }
        if let v = endDate, !v.isEmpty { params["endDate"] = v }
        return try await network.get("ActivityLog", parameters: params)
    }

    func getEntityHistory(entityType: String, entityId: Int) async throws -> [ActivityLogDto] {
        return try await network.get("ActivityLog/\(entityType)/\(entityId)")
    }
}
