import Foundation

struct SiteHoursUi: Identifiable {
    var id: Int { shiftId }
    let shiftId: Int
    let projectName: String
    let address: String
    let clientName: String
    let totalHours: Double
    let doerCount: Int
    let isOverThreshold: Bool
    let isApproachingThreshold: Bool
    let stages: [StageHoursDto]
    var doerHours: [DoerHoursUi]
    var isExpanded: Bool = false

    var totalHoursFormatted: String {
        let h = Int(totalHours)
        let m = Int((totalHours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
}

struct DoerHoursUi: Identifiable {
    var id: String { "\(userId)_\(shiftId)" }
    let userId: String
    let displayName: String
    let shiftId: Int
    let clockInTime: String
    let clockOutTime: String
    let totalHours: Double
    let stage: String
    let isActive: Bool
    let isOverThreshold: Bool
    let sessions: [SessionUi]
    var isExpanded: Bool = false

    var totalHoursFormatted: String {
        let h = Int(totalHours)
        let m = Int((totalHours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
}

struct SessionUi: Identifiable {
    let id = UUID()
    let date: String             // "2026-04-15"
    let clockInTime: String      // "HH:mm"
    let clockOutTime: String     // "HH:mm" or "" for active
    let hours: Double
    let stage: String
    let isActive: Bool

    var hoursFormatted: String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }

    var displayDate: String {
        // "2026-04-15" → "15 Apr 2026"
        let parts = date.split(separator: "-").map(String.init)
        guard parts.count == 3, let day = Int(parts[2]), let monthNum = Int(parts[1]),
              monthNum >= 1, monthNum <= 12 else { return date }
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return "\(day) \(months[monthNum - 1]) \(parts[0])"
    }
}

@MainActor
class TimeTrackingDashboardViewModel: ObservableObject {
    @Published var sites: [SiteHoursUi] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var selectedDate = Date()
    @Published var totalSites = 0
    @Published var totalDoers = 0
    @Published var totalHours: Double = 0
    @Published var alertCount = 0

    // Edit dialog
    @Published var editingDoer: DoerHoursUi?
    @Published var editClockIn = ""
    @Published var editClockOut = ""
    @Published var editReason = ""

    private let timeTrackingRepo = DIContainer.shared.timeTrackingRepository
    private let trackingRepo = DIContainer.shared.trackingRepository
    private let prefs = DIContainer.shared.preferencesManager

    private let apiDateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init() {
        loadData()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        loadData()
    }

    func toggleExpanded(_ shiftId: Int) {
        if let idx = sites.firstIndex(where: { $0.shiftId == shiftId }) {
            sites[idx].isExpanded.toggle()
        }
    }

    func toggleDoerExpanded(shiftId: Int, userId: String) {
        guard let siteIdx = sites.firstIndex(where: { $0.shiftId == shiftId }) else { return }
        guard let doerIdx = sites[siteIdx].doerHours.firstIndex(where: { $0.userId == userId }) else { return }
        sites[siteIdx].doerHours[doerIdx].isExpanded.toggle()
    }

    func refresh() { loadData() }

    func editTimeEntry() {
        guard let doer = editingDoer, !editReason.isEmpty else { return }
        let dateStr = apiDateFormat.string(from: selectedDate)
        let clockIn = editClockIn.isEmpty ? nil : "\(dateStr)T\(editClockIn):00"
        let clockOut = editClockOut.isEmpty ? nil : "\(dateStr)T\(editClockOut):00"

        Task {
            let request = EditTimeEntryDto(
                userId: doer.userId, shiftId: doer.shiftId,
                clockInTime: clockIn, clockOutTime: clockOut,
                reasonCode: editReason, editedBy: prefs.userId,
                lId: Constants.lId, siteId: Constants.siteId,
                basicAuthUid: prefs.basicAuthUid
            )
            _ = await trackingRepo.editTimeEntry(request)
            editingDoer = nil
            loadData()
        }
    }

    private func loadData() {
        let dateStr = apiDateFormat.string(from: selectedDate)
        Task {
            isLoading = true
            let result = await timeTrackingRepo.getSiteHoursSummary(date: dateStr)
            switch result {
            case .success(let data):
                let mapped = data.map { dto -> SiteHoursUi in
                    let doers = dto.doerHours.map { d in
                        DoerHoursUi(userId: d.userId, displayName: d.displayName,
                                    shiftId: dto.shiftId, clockInTime: d.clockInTime ?? "",
                                    clockOutTime: d.clockOutTime ?? "", totalHours: d.totalHours,
                                    stage: d.stage, isActive: d.isActive,
                                    isOverThreshold: d.totalHours >= 12.0,
                                    sessions: d.sessions.map { s in
                                        SessionUi(
                                            date: s.date,
                                            clockInTime: String(s.clockInTime.suffix(8).prefix(5)),
                                            clockOutTime: s.clockOutTime.map { String($0.suffix(8).prefix(5)) } ?? "",
                                            hours: s.hours,
                                            stage: s.stage,
                                            isActive: s.isActive
                                        )
                                    })
                    }
                    let anyOver = doers.contains { $0.isOverThreshold }
                    return SiteHoursUi(
                        shiftId: dto.shiftId, projectName: dto.projectName,
                        address: dto.address, clientName: dto.clientName ?? "",
                        totalHours: dto.totalHours, doerCount: dto.doerHours.count,
                        isOverThreshold: anyOver || dto.totalHours >= 12.0,
                        isApproachingThreshold: !anyOver && dto.totalHours >= 11.0,
                        stages: dto.stages, doerHours: doers
                    )
                }.sorted {
                    if $0.isOverThreshold != $1.isOverThreshold { return $0.isOverThreshold }
                    if $0.isApproachingThreshold != $1.isApproachingThreshold { return $0.isApproachingThreshold }
                    return $0.totalHours > $1.totalHours
                }

                sites = mapped
                isLoading = false
                totalSites = mapped.count
                totalDoers = mapped.reduce(0) { $0 + $1.doerCount }
                totalHours = mapped.reduce(0.0) { $0 + $1.totalHours }
                alertCount = mapped.filter { $0.isOverThreshold }.count +
                             mapped.flatMap { $0.doerHours }.filter { $0.isOverThreshold }.count

            case .error(let msg, _):
                isLoading = false
                errorMessage = msg
            case .loading: break
            }
        }
    }
}
