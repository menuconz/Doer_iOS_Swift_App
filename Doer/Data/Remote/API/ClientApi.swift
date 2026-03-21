import Foundation
import Alamofire

class ClientApi {
    private let network = NetworkManager.shared

    func getAllClients() async throws -> [ClientDto] {
        return try await network.get("Client/GetAllClients")
    }

    func createNewClient(client: ClientDto) async throws -> ClientDto {
        return try await network.post("Client/CreateClient", body: client)
    }

    func updateClient(client: ClientDto) async throws -> ClientDto {
        return try await network.post("Client/UpdateClient", body: client)
    }

    func deleteClientById(id: Int) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            network.session.request(
                network.baseURL + "Client/DeleteClient",
                method: .post,
                parameters: ["id": id],
                encoding: URLEncoding.queryString
            )
            .validate()
            .responseDecodable(of: Bool.self) { response in
                switch response.result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func getUnassignedJobs() async throws -> [ClientJobDto] {
        return try await network.get("Client/GetUnassignedJobs")
    }

    func assignClientToJob(shiftId: Int, clientId: Int?) async throws -> String {
        var params: [String: Any] = ["shiftId": shiftId]
        if let clientId = clientId { params["clientId"] = clientId }
        return try await withCheckedThrowingContinuation { continuation in
            network.session.request(
                network.baseURL + "Client/AssignClientToJob",
                method: .post,
                parameters: params,
                encoding: URLEncoding.queryString
            )
            .validate()
            .responseString { response in
                switch response.result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}
