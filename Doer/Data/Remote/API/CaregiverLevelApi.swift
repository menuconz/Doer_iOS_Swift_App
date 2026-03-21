import Foundation

class CaregiverLevelApi {
    private let network = NetworkManager.shared

    func getAllCaregiverLevels() async throws -> [CaregiverLevelDto] {
        return try await network.get("CaregiverLevels/GetCaregiverLevels")
    }
}
