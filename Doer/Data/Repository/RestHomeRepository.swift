import Foundation

class RestHomeRepository {
    private let restHomeApi: RestHomeApi

    init(restHomeApi: RestHomeApi = RestHomeApi()) {
        self.restHomeApi = restHomeApi
    }

    func registerRestHome(restHome: RestHomeDto) async -> ApiResult<RestHomeDto> {
        await safeApiCall { try await self.restHomeApi.registerRestHome(restHome: restHome) }
    }

    func getRestHomes() async -> ApiResult<[RestHomeDto]> {
        await safeApiCall { try await self.restHomeApi.getRestHomes() }
    }

    func getRestHomeById(id: Int) async -> ApiResult<RestHomeDto> {
        await safeApiCall { try await self.restHomeApi.getRestHomeById(id: id) }
    }
}
