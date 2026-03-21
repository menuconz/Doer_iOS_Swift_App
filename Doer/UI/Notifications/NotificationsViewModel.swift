import Foundation

struct NotificationGroup: Identifiable {
    let id = UUID()
    let dateLabel: String
    let dateKey: String
    let notifications: [NotificationsDto]
}

@Observable
class NotificationsViewModel {
    var isLoading: Bool = true
    var isRefreshing: Bool = false
    var groups: [NotificationGroup] = []
    var unreadCount: Int = 0
    var errorMessage: String? = nil
    var navigateToShift: (String, Int)? = nil
    var navigateToMessages: Int? = nil

    private let shiftRepository: ShiftRepository
    private let preferencesManager: PreferencesManager
    private var hasLoaded = false

    init(
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        preferencesManager: PreferencesManager = PreferencesManager.shared
    ) {
        self.shiftRepository = shiftRepository
        self.preferencesManager = preferencesManager
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadNotifications()
    }

    func loadNotifications() {
        Task { @MainActor in
            let userId = preferencesManager.userId
            let result = await shiftRepository.getUserAllNotificationsById(userId: userId)
            switch result {
            case .success(let notifications):
                let grouped = Dictionary(grouping: notifications) { getDateKey($0.sentAt) }
                    .sorted { $0.key > $1.key }
                    .map { (dateKey, items) in
                        NotificationGroup(
                            dateLabel: formatDateLabel(dateKey),
                            dateKey: dateKey,
                            notifications: items.sorted { $0.sentAt > $1.sentAt }
                        )
                    }
                groups = grouped
                unreadCount = notifications.filter { !$0.isRead }.count
                isLoading = false
                isRefreshing = false
            case .error(let message, _):
                isLoading = false
                isRefreshing = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    func refresh() {
        isRefreshing = true
        loadNotifications()
    }

    func onNotificationTapped(_ notification: NotificationsDto) {
        Task { @MainActor in
            if !notification.isRead {
                _ = await shiftRepository.markNotificationAsRead(id: notification.id)
                groups = groups.map { group in
                    NotificationGroup(
                        dateLabel: group.dateLabel,
                        dateKey: group.dateKey,
                        notifications: group.notifications.map {
                            if $0.id == notification.id {
                                var updated = $0
                                updated.isRead = true
                                return updated
                            }
                            return $0
                        }
                    )
                }
                unreadCount = max(unreadCount - 1, 0)
            }

            let shiftId = notification.shiftId ?? 0
            if notification.notificationType == "email_message" && notification.emailMessageId != nil && shiftId > 0 {
                navigateToMessages = shiftId
            } else if shiftId > 0 {
                let shiftResult = await shiftRepository.getShiftById(id: shiftId)
                if case .success(let shift) = shiftResult {
                    let dateComponent = shift.durationFrom.components(separatedBy: "T").first
                    let date: String
                    if let d = dateComponent, !d.isEmpty {
                        date = d
                    } else {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        date = formatter.string(from: Date())
                    }
                    navigateToShift = (date, shiftId)
                } else {
                    errorMessage = "Job details not found."
                }
            } else {
                errorMessage = "This notification type is not yet supported."
            }
        }
    }

    func clearNavigation() {
        navigateToShift = nil
        navigateToMessages = nil
    }

    func clearError() { errorMessage = nil }

    func formatTime(_ sentAt: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let cleaned = sentAt.replacingOccurrences(of: "Z", with: "")
        if let date = formatter.date(from: cleaned) {
            formatter.dateFormat = "MMM dd, HH:mm"
            return formatter.string(from: date)
        }
        return sentAt
    }

    private func getDateKey(_ sentAt: String) -> String {
        return sentAt.components(separatedBy: "T").first ?? sentAt
    }

    private func formatDateLabel(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        formatter.dateFormat = "MMMM dd, yyyy"
        return formatter.string(from: date)
    }
}
