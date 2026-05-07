import Foundation

class ActivityLogRepository {
    private let api: ActivityLogApi

    init(api: ActivityLogApi = ActivityLogApi()) {
        self.api = api
    }

    func getLogs(
        entityType: String? = nil,
        entityId: Int? = nil,
        userId: String? = nil,
        action: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        skip: Int = 0,
        take: Int = 50
    ) async -> ApiResult<ActivityLogPagedDto> {
        await safeApiCall {
            try await self.api.getLogs(
                entityType: entityType,
                entityId: entityId,
                userId: userId,
                action: action,
                startDate: startDate,
                endDate: endDate,
                skip: skip,
                take: take
            )
        }
    }

    func getEntityHistory(entityType: String, entityId: Int) async -> ApiResult<[ActivityLogDto]> {
        await safeApiCall { try await self.api.getEntityHistory(entityType: entityType, entityId: entityId) }
    }
}
