import Foundation

class TimeTrackingRepository {
    private let timeTrackingApi: TimeTrackingApi
    private let prefs: PreferencesManager

    init(timeTrackingApi: TimeTrackingApi, prefs: PreferencesManager) {
        self.timeTrackingApi = timeTrackingApi
        self.prefs = prefs
    }

    func getSiteHoursSummary(date: String? = nil, dateFrom: String? = nil, dateTo: String? = nil) async -> ApiResult<[SiteHoursSummaryDto]> {
        do {
            // Managers and admins see all workers' hours for the site, not just their own.
            // Contractors / caregivers see only their own hours.
            let userIdFilter = (prefs.isManager || prefs.isAdmin) ? "" : prefs.userId

            let filter = TimeTrackingFilterDto(
                date: date,
                dateFrom: dateFrom,
                dateTo: dateTo,
                userId: userIdFilter,
                lId: Constants.lId,
                siteId: Constants.siteId,
                basicAuthUid: prefs.basicAuthUid
            )
            let result = try await timeTrackingApi.getSiteHoursSummary(filter: filter)
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
