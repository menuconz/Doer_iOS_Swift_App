import Foundation
import SwiftUI

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: String
    let isCurrentMonth: Bool
    let isToday: Bool
    var extraEventsCount: Int = 0
}

struct CalendarWeek: Identifiable {
    let id = UUID()
    let days: [CalendarDay]
    let multiDayEvents: [MultiDayEvent]
}

struct MultiDayEvent: Identifiable {
    let id: Int
    let title: String
    let color: Color
    let shift: ShiftDto
    let startDate: Date
    let endDate: Date
    let startColumn: Int
    let columnSpan: Int
    let level: Int
}

@Observable
class CalendarViewModel {
    var currentMonthYear: String = ""
    var currentMonth: Int = Calendar.current.component(.month, from: Date())
    var currentYear: Int = Calendar.current.component(.year, from: Date())
    var weeks: [CalendarWeek] = []
    var isLoading: Bool = false
    var isAdmin: Bool = false
    var isManager: Bool = false
    var isCaregiver: Bool = false
    var isCustomer: Bool = false

    private let shiftRepository: ShiftRepository
    private let preferencesManager: PreferencesManager
    private let boardConfigCache: BoardConfigCache
    private var shiftsCache: [String: [ShiftDto]] = [:]
    private let calendar = Calendar.current

    private var hasLoaded = false

    init(
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager,
        boardConfigCache: BoardConfigCache = DIContainer.shared.boardConfigCache
    ) {
        self.shiftRepository = shiftRepository
        self.preferencesManager = preferencesManager
        self.boardConfigCache = boardConfigCache

        isAdmin = preferencesManager.isAdmin
        isManager = preferencesManager.isManager || preferencesManager.isCustomer
        isCaregiver = preferencesManager.isCaregiver
        isCustomer = preferencesManager.isCustomer
    }

    // Cache-aware contract-type color used to paint multi-day event chips.
    func contractTypeColorDynamic(_ value: Int?) -> Color {
        if let hex = boardConfigCache.getOptions("ContractType")
            .first(where: { $0.value == value ?? -1 })?.color,
           let argb = BoardConfigCache.parseHexColor(hex) {
            return Color(argb: argb)
        }
        return Self.getContractTypeColor(value)
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadMonth(month: currentMonth, year: currentYear)
        Task { await preloadAdjacentMonths(month: currentMonth, year: currentYear) }
    }

    /// Refresh on every onAppear (matches Android ON_RESUME behavior)
    func refreshOnAppear() {
        if !hasLoaded {
            loadInitialData()
        } else {
            refresh()
        }
    }

    private func preloadAdjacentMonths(month: Int, year: Int) async {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = calendar.date(from: comps),
              let prev = calendar.date(byAdding: .month, value: -1, to: date),
              let next = calendar.date(byAdding: .month, value: 1, to: date) else { return }
        let prevMonth = calendar.component(.month, from: prev)
        let prevYear = calendar.component(.year, from: prev)
        let nextMonth = calendar.component(.month, from: next)
        let nextYear = calendar.component(.year, from: next)
        // Only fetch if not already cached
        async let _ = getShiftsForMonth(month: prevMonth, year: prevYear)
        async let _ = getShiftsForMonth(month: nextMonth, year: nextYear)
    }

    func refresh() {
        shiftsCache.removeAll()
        loadMonth(month: currentMonth, year: currentYear)
    }

    func previousMonth() {
        var comps = DateComponents()
        comps.year = currentYear
        comps.month = currentMonth
        comps.day = 1
        guard let date = calendar.date(from: comps),
              let prev = calendar.date(byAdding: .month, value: -1, to: date) else { return }
        let m = calendar.component(.month, from: prev)
        let y = calendar.component(.year, from: prev)
        loadMonth(month: m, year: y)
    }

    func nextMonth() {
        var comps = DateComponents()
        comps.year = currentYear
        comps.month = currentMonth
        comps.day = 1
        guard let date = calendar.date(from: comps),
              let next = calendar.date(byAdding: .month, value: 1, to: date) else { return }
        let m = calendar.component(.month, from: next)
        let y = calendar.component(.year, from: next)
        loadMonth(month: m, year: y)
    }

    private var loadingMonths: Set<String> = []

    private func loadMonth(month: Int, year: Int) {
        let cacheKey = "\(year)-\(String(format: "%02d", month))"
        let isCached = shiftsCache[cacheKey] != nil

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = calendar.date(from: comps) else { return }
        formatter.dateFormat = "MMMM yyyy"
        let monthYearStr = formatter.string(from: date)

        currentMonth = month
        currentYear = year
        currentMonthYear = monthYearStr
        weeks = isCached
            ? generateCalendarWeeks(month: month, year: year, shifts: shiftsCache[cacheKey]!)
            : generateCalendarWeeks(month: month, year: year, shifts: [])
        isLoading = !isCached

        if isCached { return }

        // Prevent duplicate fetches for the same month
        guard !loadingMonths.contains(cacheKey) else { return }
        loadingMonths.insert(cacheKey)

        Task { @MainActor in
            let shifts = await getShiftsForMonth(month: month, year: year)
            loadingMonths.remove(cacheKey)
            let generatedWeeks = generateCalendarWeeks(month: month, year: year, shifts: shifts)
            if currentMonth == month && currentYear == year {
                weeks = generatedWeeks
                isLoading = false
            }
        }
    }

    private func getShiftsForMonth(month: Int, year: Int) async -> [ShiftDto] {
        let cacheKey = "\(year)-\(String(format: "%02d", month))"
        if let cached = shiftsCache[cacheKey] { return cached }

        let result: ApiResult<[ShiftDto]>
        if isAdmin {
            result = await shiftRepository.getShiftsForApp(month: month, year: year)
        } else {
            let userId = preferencesManager.userId
            result = await shiftRepository.getShiftsByUserIdMonth(userId: userId, month: month, year: year)
        }

        let shifts: [ShiftDto]
        switch result {
        case .success(let data): shifts = data
        case .error: shifts = []
        case .loading: shifts = []
        }

        shiftsCache[cacheKey] = shifts
        return shifts
    }

    private func generateCalendarWeeks(month: Int, year: Int, shifts: [ShiftDto]) -> [CalendarWeek] {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let firstDayOfMonth = calendar.date(from: comps) else { return [] }
        guard let rangeOfMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else { return [] }
        comps.day = rangeOfMonth.count
        guard let lastDayOfMonth = calendar.date(from: comps) else { return [] }
        let today = calendar.startOfDay(for: Date())

        // Find Monday of the first week (ISO: Monday=2)
        var startDate = firstDayOfMonth
        while calendar.component(.weekday, from: startDate) != 2 { // Monday
            startDate = calendar.date(byAdding: .day, value: -1, to: startDate)!
        }

        // Find Sunday of the last week
        var endDate = lastDayOfMonth
        while calendar.component(.weekday, from: endDate) != 1 { // Sunday
            endDate = calendar.date(byAdding: .day, value: 1, to: endDate)!
        }

        // Parse shifts into events (normalize to start of day for correct calendar display)
        let events: [(shift: ShiftDto, from: Date, to: Date)] = shifts.compactMap { shift in
            guard let from = Self.parseDate(shift.durationFrom),
                  let to = Self.parseDate(shift.durationTo) else { return nil }
            return (shift, calendar.startOfDay(for: from), calendar.startOfDay(for: to))
        }

        var weeks: [CalendarWeek] = []
        var weekStart = startDate
        while weekStart <= endDate {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            let days = (0..<7).map { offset -> CalendarDay in
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                let dateMonth = calendar.component(.month, from: date)
                return CalendarDay(
                    date: date,
                    dayNumber: dateMonth == month ? "\(calendar.component(.day, from: date))" : "",
                    isCurrentMonth: dateMonth == month,
                    isToday: calendar.isDate(date, inSameDayAs: today)
                )
            }

            let (weekEvents, hiddenPerDay) = getWeekEvents(events: events, weekStart: weekStart, weekEnd: weekEnd)

            let updatedDays = days.map { day -> CalendarDay in
                let dateKey = calendar.startOfDay(for: day.date)
                let hidden = hiddenPerDay[dateKey] ?? 0
                if hidden > 0 {
                    var d = day
                    d.extraEventsCount = hidden
                    return d
                }
                return day
            }

            weeks.append(CalendarWeek(days: updatedDays, multiDayEvents: weekEvents))
            weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        }

        return weeks
    }

    private func getWeekEvents(events: [(shift: ShiftDto, from: Date, to: Date)], weekStart: Date, weekEnd: Date) -> ([MultiDayEvent], [Date: Int]) {
        let weekEvents = events.filter { $0.from <= weekEnd && $0.to >= weekStart }

        var multiDayEvents: [MultiDayEvent] = []
        var hiddenPerDay: [Date: Int] = [:]

        let sortedEvents = weekEvents.sorted { a, b in
            if a.from != b.from { return a.from < b.from }
            let daysA = calendar.dateComponents([.day], from: a.from, to: a.to).day ?? 0
            let daysB = calendar.dateComponents([.day], from: b.from, to: b.to).day ?? 0
            if daysA != daysB { return daysA > daysB }
            return a.shift.id < b.shift.id
        }

        for event in sortedEvents {
            let clippedStart = max(event.from, weekStart)
            let clippedEnd = min(event.to, weekEnd)
            let startColumn = isoDayIndex(clippedStart) // Monday=0
            let daysBetween = calendar.dateComponents([.day], from: clippedStart, to: clippedEnd).day ?? 0
            let columnSpan = daysBetween + 1

            var level = 0
            while multiDayEvents.contains(where: { existing in
                existing.level == level &&
                existing.startColumn < startColumn + columnSpan &&
                existing.startColumn + existing.columnSpan > startColumn
            }) {
                level += 1
            }

            if level < 3 {
                multiDayEvents.append(MultiDayEvent(
                    id: event.shift.id,
                    title: event.shift.projectName.isEmpty ? event.shift.address : event.shift.projectName,
                    color: contractTypeColorDynamic(event.shift.contractType),
                    shift: event.shift,
                    startDate: event.from,
                    endDate: event.to,
                    startColumn: startColumn,
                    columnSpan: columnSpan,
                    level: level
                ))
            } else {
                var date = clippedStart
                while date <= clippedEnd {
                    let key = calendar.startOfDay(for: date)
                    hiddenPerDay[key, default: 0] += 1
                    date = calendar.date(byAdding: .day, value: 1, to: date)!
                }
            }
        }

        return (multiDayEvents, hiddenPerDay)
    }

    private func isoDayIndex(_ date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        // Convert from Sunday=1..Saturday=7 to Monday=0..Sunday=6
        return (weekday + 5) % 7
    }

    static func parseDate(_ dateStr: String) -> Date? {
        if dateStr.isEmpty { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Try ISO format first
        let cleaned = String(dateStr.prefix(19))
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: cleaned) { return date }
        // Try date-only
        formatter.dateFormat = "yyyy-MM-dd"
        let dateOnly = String(dateStr.prefix(10))
        return formatter.date(from: dateOnly)
    }

    static func getContractTypeColor(_ contractType: Int?) -> Color {
        switch contractType {
        case 1:  return Color(hex: "C4C4C4")
        case 2:  return Color(hex: "BCA58A")
        case 3:  return Color(hex: "74AFCC")
        case 4:  return Color(hex: "CAB641")
        case 5:  return Color(hex: "175A63")
        case 6:  return Color(hex: "333333")
        case 7:  return Color(hex: "FF0000")
        case 8:  return Color(hex: "037F4C")
        case 9:  return Color(hex: "7F5347")
        case 10: return Color(hex: "7F00FF")
        case 11: return Color(hex: "FF8DA1")
        default: return Color(hex: "8E8E93")
        }
    }

    static func getStatusColor(_ statusId: Int, hasQuotations: Bool = false) -> Color {
        switch statusId {
        case 1: return hasQuotations ? Color(hex: "007AFF") : Color(hex: "FF9500")
        case 2: return Color(hex: "9D50DD")
        case 3: return Color(hex: "00C875")
        case 4: return Color(hex: "74AFCC")
        case 5: return Color(hex: "FF3B30")
        case 6: return Color(hex: "FFCB00")
        default: return Color(hex: "8E8E93")
        }
    }
}
