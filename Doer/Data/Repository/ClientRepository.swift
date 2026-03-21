import Foundation

class ClientRepository {
    private let clientApi: ClientApi

    init(clientApi: ClientApi = ClientApi()) {
        self.clientApi = clientApi
    }

    func getAllClients() async -> ApiResult<[ClientDto]> { await safeApiCall { try await self.clientApi.getAllClients() } }
    func createNewClient(client: ClientDto) async -> ApiResult<ClientDto> { await safeApiCall { try await self.clientApi.createNewClient(client: client) } }
    func updateClient(client: ClientDto) async -> ApiResult<ClientDto> { await safeApiCall { try await self.clientApi.updateClient(client: client) } }
    func deleteClientById(id: Int) async -> ApiResult<Bool> { await safeApiCall { try await self.clientApi.deleteClientById(id: id) } }
    func getUnassignedJobs() async -> ApiResult<[ClientJobDto]> { await safeApiCall { try await self.clientApi.getUnassignedJobs() } }
    func assignClientToJob(shiftId: Int, clientId: Int?) async -> ApiResult<String> { await safeApiCall { try await self.clientApi.assignClientToJob(shiftId: shiftId, clientId: clientId) } }
}
