import Foundation

class RestHomeApi {
    private let network = NetworkManager.shared

    func registerRestHome(restHome: RestHomeDto) async throws -> RestHomeDto {
        return try await network.post("RestHome/RegisterRestHome", body: restHome)
    }

    func getRestHomes() async throws -> [RestHomeDto] {
        return try await network.get("RestHome/GetRestHomes")
    }

    func getRestHomeById(id: Int) async throws -> RestHomeDto {
        return try await network.get("RestHome/GetRestHomeById", parameters: ["Id": id])
    }
}
