import Foundation

class LogsRepository {
    private let logsApi: LogsApi
    private let prefs: PreferencesManager

    init(logsApi: LogsApi = LogsApi(), prefs: PreferencesManager = .shared) {
        self.logsApi = logsApi
        self.prefs = prefs
    }

    func enterLogs(logs: LogsDto) async -> ApiResult<LogsDto> {
        await safeApiCall { try await self.logsApi.enterLogs(logs: logs) }
    }
}
