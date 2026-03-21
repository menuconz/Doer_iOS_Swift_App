import Foundation

class LogsApi {
    private let network = NetworkManager.shared

    func enterLogs(logs: LogsDto) async throws -> LogsDto {
        return try await network.post("Common/SaveLog", body: logs)
    }
}
