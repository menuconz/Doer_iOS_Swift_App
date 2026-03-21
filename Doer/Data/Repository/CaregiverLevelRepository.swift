import Foundation

class CaregiverLevelRepository {
    private let caregiverLevelApi: CaregiverLevelApi

    init(caregiverLevelApi: CaregiverLevelApi = CaregiverLevelApi()) {
        self.caregiverLevelApi = caregiverLevelApi
    }

    func getAllCaregiverLevels() async -> ApiResult<[CaregiverLevelDto]> {
        await safeApiCall { try await self.caregiverLevelApi.getAllCaregiverLevels() }
    }
}
