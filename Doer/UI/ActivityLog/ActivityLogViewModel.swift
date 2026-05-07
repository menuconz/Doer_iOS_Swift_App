import Foundation
import SwiftUI

@Observable
@MainActor
class ActivityLogViewModel {
    private let repository: ActivityLogRepository

    var isLoading: Bool = false
    var logs: [ActivityLogDto] = []
    var totalCount: Int = 0
    var skip: Int = 0
    var take: Int = 50
    var canLoadMore: Bool = true
    var errorMessage: String? = nil

    var entityTypeFilter: String? = nil
    var actionFilter: String? = nil

    init(repository: ActivityLogRepository = DIContainer.shared.activityLogRepository) {
        self.repository = repository
    }

    static let entityTypes: [(label: String, value: String?)] = [
        ("All", nil),
        ("Shift", "Shift"),
        ("Sub-Item", "ShiftSubItem"),
        ("Lead", "Lead"),
        ("User", "User"),
        ("Board", "Board"),
        ("Dropdown", "DropdownOption"),
        ("Client", "Client")
    ]

    static let actions: [(label: String, value: String?)] = [
        ("All", nil),
        ("Created", "Created"),
        ("Updated", "Updated"),
        ("Deleted", "Deleted"),
        ("Status Change", "StatusChanged"),
        ("Role Change", "RoleChanged")
    ]

    func loadFirstPage() {
        skip = 0
        logs = []
        canLoadMore = true
        fetch()
    }

    func loadMore() {
        if !canLoadMore || isLoading { return }
        fetch()
    }

    func setEntityTypeFilter(_ value: String?) {
        entityTypeFilter = value
        loadFirstPage()
    }

    func setActionFilter(_ value: String?) {
        actionFilter = value
        loadFirstPage()
    }

    func clearFilters() {
        entityTypeFilter = nil
        actionFilter = nil
        loadFirstPage()
    }

    func clearError() { errorMessage = nil }

    private func fetch() {
        let currentSkip = skip
        isLoading = true
        Task { @MainActor in
            switch await repository.getLogs(
                entityType: entityTypeFilter,
                entityId: nil,
                userId: nil,
                action: actionFilter,
                startDate: nil,
                endDate: nil,
                skip: currentSkip,
                take: take
            ) {
            case .success(let paged):
                let newLogs = currentSkip == 0 ? paged.logs : (logs + paged.logs)
                logs = newLogs
                totalCount = paged.totalCount
                skip = newLogs.count
                canLoadMore = newLogs.count < paged.totalCount
                isLoading = false
            case .error(let msg, _):
                isLoading = false
                errorMessage = msg
            case .loading: break
            }
        }
    }
}
