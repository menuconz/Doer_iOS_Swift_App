import Foundation
import SwiftUI

struct CalendarDayItem: Identifiable {
    let id = UUID()
    let date: Date
    let dayLetter: String
    let dayNumber: String
    let monthName: String
    let isSelected: Bool
    let isToday: Bool

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct DayShiftItem: Identifiable {
    let id = UUID()
    let shift: ShiftDto
    let projectName: String
    let address: String
    let durationText: String
    let statusMessage: String
    let contractColor: Color
}

struct TimelineBlock: Identifiable {
    let id = UUID()
    let shift: ShiftDto
    let projectName: String
    let address: String
    let durationText: String
    let contractColor: Color
    let startHour: Double
    let durationHours: Double
    let columnIndex: Int
    var totalColumns: Int
}

@Observable
class DayTimelineViewModel {
    var selectedDate: Date = Date()
    var pageTitle: String = ""
    var calendarDays: [CalendarDayItem] = []
    var totalJobs: Int = 0
    var allDayJobs: [DayShiftItem] = []
    var timelineBlocks: [TimelineBlock] = []
    var dayShifts: [DayShiftItem] = []
    var isLoading: Bool = false
    var isManager: Bool = false
    var isAdmin: Bool = false

    private let shiftRepository: ShiftRepository
    private let preferencesManager: PreferencesManager
    private let boardConfigCache: BoardConfigCache
    private let calendar = Calendar.current
    private var earliestDate: Date
    private var latestDate: Date
    private var hasLoaded = false
    private var initialDate: Date = Date()
    var isLoadingMoreDates = false

    init(
        date: String = "",
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager,
        boardConfigCache: BoardConfigCache = DIContainer.shared.boardConfigCache
    ) {
        self.shiftRepository = shiftRepository
        self.preferencesManager = preferencesManager
        self.boardConfigCache = boardConfigCache
        self.earliestDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        self.latestDate = Calendar.current.date(byAdding: .day, value: 90, to: Date())!

        isAdmin = preferencesManager.isAdmin
        isManager = preferencesManager.isManager || preferencesManager.isCustomer

        if !date.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            initialDate = formatter.date(from: date) ?? Date()
        } else {
            initialDate = Date()
        }
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        selectDate(initialDate)
    }

    func checkAndLoadMore(dayItem: CalendarDayItem) {
        guard !isLoadingMoreDates else { return }
        guard let index = calendarDays.firstIndex(where: { $0.dateString == dayItem.dateString }) else { return }
        if index <= 5 {
            loadMorePastDates()
        } else if index >= calendarDays.count - 5 {
            loadMoreFutureDates()
        }
    }

    func refresh() {
        Task { @MainActor in
            await loadShiftsForDate(selectedDate)
        }
    }

    // Cache-aware contract-type color used by timeline blocks.
    func contractTypeColorDynamic(_ value: Int?) -> Color {
        if let hex = boardConfigCache.getOptions("ContractType")
            .first(where: { $0.value == value ?? -1 })?.color,
           let argb = BoardConfigCache.parseHexColor(hex) {
            return Color(argb: argb)
        }
        return CalendarViewModel.getContractTypeColor(value)
    }

    func selectDate(_ date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE -- MMM d, yyyy"
        let title = formatter.string(from: date).replacingOccurrences(of: "--", with: "\u{2014}")

        selectedDate = date
        pageTitle = title
        calendarDays = generateCalendarDays(selectedDate: date)
        isLoading = true

        Task { @MainActor in
            await loadShiftsForDate(date)
        }
    }

    private func generateCalendarDays(selectedDate: Date) -> [CalendarDayItem] {
        if let earlyCheck = calendar.date(byAdding: .day, value: -15, to: selectedDate),
           earlyCheck < earliestDate {
            earliestDate = earlyCheck
        }
        if let lateCheck = calendar.date(byAdding: .day, value: 15, to: selectedDate),
           lateCheck > latestDate {
            latestDate = lateCheck
        }

        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: selectedDate)
        var days: [CalendarDayItem] = []
        var date = earliestDate
        while date <= latestDate {
            days.append(createCalendarDayItem(date: date, selectedDate: selectedDay, today: today))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return days
    }

    private func createCalendarDayItem(date: Date, selectedDate: Date, today: Date) -> CalendarDayItem {
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US")
        dayFormatter.dateFormat = "EEEEE"
        let dayLetter = dayFormatter.string(from: date).uppercased()

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US")
        monthFormatter.dateFormat = "MMM"
        let monthName = monthFormatter.string(from: date)

        return CalendarDayItem(
            date: date,
            dayLetter: String(dayLetter.prefix(1)),
            dayNumber: "\(calendar.component(.day, from: date))",
            monthName: monthName,
            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
            isToday: calendar.isDate(date, inSameDayAs: today)
        )
    }

    func loadMorePastDates() {
        guard !isLoadingMoreDates else { return }
        isLoadingMoreDates = true
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: selectedDate)
        guard let newEarliest = calendar.date(byAdding: .day, value: -10, to: earliestDate) else {
            isLoadingMoreDates = false
            return
        }
        var newDays: [CalendarDayItem] = []
        var date = newEarliest
        while date < earliestDate {
            newDays.append(createCalendarDayItem(date: date, selectedDate: selectedDay, today: today))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        earliestDate = newEarliest
        calendarDays = newDays + calendarDays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            isLoadingMoreDates = false
        }
    }

    func loadMoreFutureDates() {
        guard !isLoadingMoreDates else { return }
        isLoadingMoreDates = true
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: selectedDate)
        guard let newLatest = calendar.date(byAdding: .day, value: 10, to: latestDate) else {
            isLoadingMoreDates = false
            return
        }
        var newDays: [CalendarDayItem] = []
        var date = calendar.date(byAdding: .day, value: 1, to: latestDate)!
        while date <= newLatest {
            newDays.append(createCalendarDayItem(date: date, selectedDate: selectedDay, today: today))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        latestDate = newLatest
        calendarDays = calendarDays + newDays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            isLoadingMoreDates = false
        }
    }

    private func loadShiftsForDate(_ date: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        let result: ApiResult<[ShiftDto]>
        if isAdmin {
            result = await shiftRepository.getShiftsByDate(selectedDate: dateStr)
        } else {
            let userId = preferencesManager.userId
            result = await shiftRepository.getShiftsByUserIdAndDate(userId: userId, selectedDate: dateStr)
        }

        let shifts: [ShiftDto]
        switch result {
        case .success(let data): shifts = data.sorted { $0.id > $1.id }
        case .error: shifts = []
        case .loading: shifts = []
        }

        let allDayShifts = shifts.filter { $0.isAllDay }
        let timedShifts = shifts.filter { !$0.isAllDay }

        let allDayItems = allDayShifts.map { createDayShiftItem(shift: $0, viewDate: date) }
        let dayShiftItems = shifts.sorted { $0.durationFrom < $1.durationFrom }.map { createDayShiftItem(shift: $0, viewDate: date) }
        let blocks = createTimelineBlocks(shifts: timedShifts, viewDate: date)

        totalJobs = shifts.count
        allDayJobs = allDayItems
        dayShifts = dayShiftItems
        timelineBlocks = blocks
        isLoading = false
    }

    private func createDayShiftItem(shift: ShiftDto, viewDate: Date) -> DayShiftItem {
        let fromDate = parseLocalDate(shift.durationFrom)
        let toDate = parseLocalDate(shift.durationTo)
        let isMultiDay = fromDate != nil && toDate != nil && !calendar.isDate(fromDate!, inSameDayAs: toDate!)

        var projectName = shift.projectName.isEmpty ? "Unnamed Job" : shift.projectName
        var durationText = ""

        if isMultiDay, let from = fromDate, let to = toDate {
            let dayNumber = (calendar.dateComponents([.day], from: from, to: viewDate).day ?? 0) + 1
            let totalDays = (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
            projectName = "\(projectName) (Day \(dayNumber)/\(totalDays))"

            if calendar.isDate(viewDate, inSameDayAs: from) {
                durationText = "\(formatTime(shift.durationFrom)) - 11:59 PM"
            } else if calendar.isDate(viewDate, inSameDayAs: to) {
                durationText = "12:00 AM - \(formatTime(shift.durationTo))"
            } else {
                durationText = "\(shift.durationFrom) - \(shift.durationTo)"
            }
        } else {
            durationText = "\(formatTime(shift.durationFrom)) - \(formatTime(shift.durationTo))"
        }

        let statusMessage = getStatusMessage(statusId: shift.statusId, hasQuotations: shift.hasQuotations)

        return DayShiftItem(
            shift: shift,
            projectName: projectName,
            address: shift.address,
            durationText: durationText,
            statusMessage: statusMessage,
            contractColor: contractTypeColorDynamic(shift.contractType)
        )
    }

    private func createTimelineBlocks(shifts: [ShiftDto], viewDate: Date) -> [TimelineBlock] {
        struct BlockData {
            let shift: ShiftDto
            let startHour: Double
            let durationHours: Double
            let projectName: String
            let durationText: String
        }

        let blocks: [BlockData] = shifts.compactMap { shift in
            let fromDate = parseLocalDate(shift.durationFrom)
            let toDate = parseLocalDate(shift.durationTo)
            let isMultiDay = fromDate != nil && toDate != nil && !calendar.isDate(fromDate!, inSameDayAs: toDate!)

            var startHour: Double
            var endHour: Double
            var durationText: String
            var projectName = shift.projectName.isEmpty ? "Unnamed Job" : shift.projectName

            if isMultiDay, let from = fromDate, let to = toDate {
                let dayNumber = (calendar.dateComponents([.day], from: from, to: viewDate).day ?? 0) + 1
                let totalDays = (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
                projectName = "\(projectName) (Day \(dayNumber)/\(totalDays))"

                if calendar.isDate(viewDate, inSameDayAs: from) {
                    startHour = parseTimeHours(shift.durationFrom)
                    endHour = 23.99
                    durationText = "\(formatTime(shift.durationFrom)) - 11:59 PM"
                } else if calendar.isDate(viewDate, inSameDayAs: to) {
                    startHour = 0.0
                    let rawEnd = parseTimeHours(shift.durationTo)
                    endHour = rawEnd == 0.0 ? 0.1 : rawEnd
                    durationText = "12:00 AM - \(formatTime(shift.durationTo))"
                } else {
                    startHour = 0.0
                    endHour = 23.99
                    durationText = "All Day"
                }
            } else {
                startHour = parseTimeHours(shift.durationFrom)
                let rawEnd = parseTimeHours(shift.durationTo)
                endHour = rawEnd <= startHour ? rawEnd + 24 : rawEnd
                durationText = "\(formatTime(shift.durationFrom)) - \(formatTime(shift.durationTo))"
            }

            let durationHours = max(endHour - startHour, 0.5)
            return BlockData(shift: shift, startHour: startHour, durationHours: durationHours, projectName: projectName, durationText: durationText)
        }.sorted { $0.startHour < $1.startHour }

        var result: [TimelineBlock] = []
        var columns: [[BlockData]] = []

        for block in blocks {
            var assignedCol = -1
            for i in columns.indices {
                let canFit = columns[i].allSatisfy { existing in
                    let existEnd = existing.startHour + existing.durationHours
                    return block.startHour >= existEnd || (block.startHour + block.durationHours) <= existing.startHour
                }
                if canFit {
                    assignedCol = i
                    break
                }
            }
            if assignedCol == -1 {
                columns.append([])
                assignedCol = columns.count - 1
            }
            columns[assignedCol].append(block)

            result.append(TimelineBlock(
                shift: block.shift,
                projectName: block.projectName,
                address: block.shift.address,
                durationText: block.durationText,
                contractColor: contractTypeColorDynamic(block.shift.contractType),
                startHour: block.startHour,
                durationHours: block.durationHours,
                columnIndex: assignedCol,
                totalColumns: 0
            ))
        }

        let totalCols = max(columns.count, 1)
        return result.map { var b = $0; b.totalColumns = totalCols; return b }
    }

    private func parseLocalDate(_ dateStr: String) -> Date? {
        if dateStr.isEmpty { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dateOnly = String(dateStr.prefix(10))
        return formatter.date(from: dateOnly)
    }

    private func parseTimeHours(_ dateStr: String) -> Double {
        guard dateStr.count >= 19 else { return 0.0 }
        let timeStr = String(dateStr[dateStr.index(dateStr.startIndex, offsetBy: 11)..<dateStr.index(dateStr.startIndex, offsetBy: 19)])
        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2,
              let hour = Double(parts[0]),
              let minute = Double(parts[1]) else { return 0.0 }
        return hour + minute / 60.0
    }

    private func formatTime(_ dateStr: String) -> String {
        guard dateStr.count >= 19 else { return "" }
        let timeStr = String(dateStr[dateStr.index(dateStr.startIndex, offsetBy: 11)..<dateStr.index(dateStr.startIndex, offsetBy: 19)])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm:ss"
        guard let time = formatter.date(from: timeStr) else { return "" }
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }

    private func getStatusMessage(statusId: Int, hasQuotations: Bool) -> String {
        switch statusId {
        case 1: return hasQuotations ? "Quoted" : "Created"
        case 2: return "Accepted"
        case 3: return "Started"
        case 4: return "End"
        case 5: return "Not Completed"
        case 6: return "Completed"
        default: return "Unknown"
        }
    }

    var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }
}
