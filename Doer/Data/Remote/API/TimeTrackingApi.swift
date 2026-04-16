import Foundation

class TimeTrackingApi {
    private let network = NetworkManager.shared

    func getSiteHoursSummary(filter: TimeTrackingFilterDto) async throws -> [SiteHoursSummaryDto] {
        return try await network.post("Tracking/SiteHoursSummary", body: filter)
    }
}
