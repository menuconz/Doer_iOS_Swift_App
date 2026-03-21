import Foundation
import Alamofire

class LocationTrackingApi {
    private let network = NetworkManager.shared

    func updateCaregiverLocation(userLocation: UserLocationDto) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            network.session.request(
                network.baseURL + "User/UpdateUserLocation",
                method: .post,
                parameters: userLocation,
                encoder: JSONParameterEncoder(encoder: NetworkManager.jsonEncoder)
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
