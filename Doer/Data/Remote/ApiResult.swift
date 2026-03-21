import Foundation

enum ApiResult<T> {
    case success(T)
    case error(String, Error? = nil)
    case loading
}

func safeApiCall<T>(_ apiCall: @escaping () async throws -> T) async -> ApiResult<T> {
    do {
        let result = try await apiCall()
        return .success(result)
    } catch {
        return .error(error.localizedDescription, error)
    }
}
