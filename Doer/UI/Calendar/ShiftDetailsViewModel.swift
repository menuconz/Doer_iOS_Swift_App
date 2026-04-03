import Foundation
import SwiftUI

struct ReminderOption: Identifiable {
    let id = UUID()
    let label: String
    let offsetMinutes: Int64
}

@Observable
class ShiftDetailsViewModel {
    // State
    var shift: ShiftDto? = nil
    var isLoading: Bool = true
    var isUpdating: Bool = false
    var errorMessage: String? = nil
    var isDeleted: Bool = false
    var successMessage: String? = nil

    // Status display
    var statusMessage: String = ""
    var statusColor: Color = Color(hex: "777777")

    // H&S Form display
    var hsFormText: String = ""
    var hsFormColor: Color = Color(hex: "C4C4C4")
    var showHsForm: Bool = false

    // Contract / Invoice display
    var contractTypeText: String = ""
    var invoiceStatusText: String = ""

    // Formatted dates
    var durationFromFormatted: String = ""
    var durationToFormatted: String = ""
    var shiftStartTimeFormatted: String = ""
    var shiftEndTimeFormatted: String = ""
    var showShiftStartTime: Bool = false
    var showShiftEndTime: Bool = false

    // Role flags
    var isManager: Bool = false
    var isCaregiver: Bool = false
    var isAdmin: Bool = false
    var isCustomer: Bool = false

    // Button visibility
    var editShiftButton: Bool = false
    var isDeleteButton: Bool = false
    var isAllDayEditable: Bool = false
    var isAllDay: Bool = false
    var quotationButton: Bool = false
    var viewQuotationsButton: Bool = false
    var startButton: Bool = false
    var rejectButton: Bool = false
    var endButton: Bool = false
    var completeButton: Bool = false
    var reviewsButton: Bool = false
    var showFeedback: Bool = false

    // Contractor details
    var contractorName: String = ""
    var contractorEmail: String = ""
    var contractorPhone: String = ""

    // Manager details
    var managerName: String = ""
    var managerEmail: String = ""
    var managerPhone: String = ""

    // Managers list for admin re-assignment
    var managersList: [UserDto] = []
    var selectedManagerId: String? = nil
    var originalManagerId: String = ""

    // Reminder
    var reminderOptions: [ReminderOption] = ShiftDetailsViewModel.defaultReminderOptions
    var selectedReminderLabel: String = "None"
    var canEditReminder: Bool = false
    var canViewReminderOnly: Bool = false
    var hasReminderSet: Bool = false
    var showReminderSection: Bool = true
    var navigateToFeedbackShiftId: Int? = nil
    var navigateToReviewsShiftId: Int? = nil

    // Private
    private let shiftRepository: ShiftRepository
    private let accountRepository: AccountRepository
    private let clientRepository: ClientRepository
    private let preferencesManager: PreferencesManager
    private let shiftId: Int
    private var hasLoaded = false

    private let displayDateFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "dd/MM/yyyy hh:mm a"
        return f
    }()

    private let parseFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm"
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
    }()

    static let defaultReminderOptions: [ReminderOption] = [
        ReminderOption(label: "None", offsetMinutes: 0),
        ReminderOption(label: "5 minutes before", offsetMinutes: 5),
        ReminderOption(label: "15 minutes before", offsetMinutes: 15),
        ReminderOption(label: "30 minutes before", offsetMinutes: 30),
        ReminderOption(label: "1 hour before", offsetMinutes: 60),
        ReminderOption(label: "2 hours before", offsetMinutes: 120),
        ReminderOption(label: "4 hours before", offsetMinutes: 240),
        ReminderOption(label: "1 day before", offsetMinutes: 1440),
        ReminderOption(label: "2 days before", offsetMinutes: 2880)
    ]

    init(
        shiftId: Int,
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        clientRepository: ClientRepository = DIContainer.shared.clientRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager
    ) {
        self.shiftId = shiftId
        self.shiftRepository = shiftRepository
        self.accountRepository = accountRepository
        self.clientRepository = clientRepository
        self.preferencesManager = preferencesManager
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadShiftDetails()
    }

    func refresh() { loadShiftDetails() }

    private func loadShiftDetails() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            let prefIsAdmin = preferencesManager.isAdmin
            let prefIsManager = preferencesManager.isManager
            let prefIsCaregiver = preferencesManager.isCaregiver
            let prefIsCustomer = preferencesManager.isCustomer

            switch await shiftRepository.getShiftById(id: shiftId) {
            case .success(var shiftData):
                // Enrich clientName
                if (shiftData.clientName ?? "").isEmpty, let clientId = shiftData.clientId, clientId > 0 {
                    if case .success(let allClients) = await clientRepository.getAllClients() {
                        if let clientName = allClients.first(where: { $0.id == clientId })?.name, !clientName.isEmpty {
                            shiftData.clientName = clientName
                        }
                    }
                }

                let statusId = shiftData.statusId
                let (statusMsg, statusClr) = getStatusDisplay(statusId, shiftData.hasQuotations)
                let hsDisplay = getHsFormDisplay(shiftData.hsForms)
                let contractText = getContractTypeText(shiftData.contractType)
                let invoiceText = getInvoiceStatusText(shiftData.invoiceStatus)
                let durationFromFmt = formatDateTime(shiftData.durationFrom)
                let durationToFmt = formatDateTime(shiftData.durationTo)
                let startTimeFmt = (shiftData.shiftStartTime?.isEmpty ?? true) ? "" : formatDateTime(shiftData.shiftStartTime!)
                let endTimeFmt = (shiftData.shiftEndTime?.isEmpty ?? true) ? "" : formatDateTime(shiftData.shiftEndTime!)

                let showStart = statusId == 3 || statusId == 4 || statusId == 6
                let showEnd = statusId == 4 || statusId == 6
                let editShift = !prefIsCaregiver && statusId != 4 && statusId != 6 && statusId != 5
                let deleteBtn = prefIsManager || prefIsAdmin
                let allDayEditable = prefIsManager || prefIsAdmin
                let quotationBtn = prefIsCaregiver && statusId == 1
                let viewQuotationsBtn = (prefIsManager || prefIsAdmin) && statusId == 1 && shiftData.hasQuotations
                let isManagerSection = (prefIsManager || prefIsCustomer || prefIsAdmin) && statusId != 1
                let startBtn = prefIsCaregiver && statusId == 2
                let rejectBtn = prefIsCaregiver && (statusId == 2 || statusId == 3)
                let endBtn = prefIsCaregiver && statusId == 3
                let completeBtn = prefIsManager && statusId == 4
                let reviewsBtn = prefIsCaregiver && statusId == 6
                let feedback = statusId == 6 && !shiftData.feedback.isEmpty

                let selectedLabel = resolveReminderLabel(shiftData.reminderOffset)
                let hasReminder = shiftData.isReminderScheduled

                let canEdit: Bool
                if prefIsManager || prefIsAdmin {
                    canEdit = editShift || statusId == 1 || statusId == 2
                } else if prefIsCaregiver {
                    canEdit = statusId == 2 || statusId == 3
                } else {
                    canEdit = false
                }
                let canViewOnly = !canEdit && hasReminder

                shift = shiftData
                isLoading = false
                statusMessage = statusMsg
                statusColor = statusClr
                hsFormText = hsDisplay?.0 ?? ""
                hsFormColor = hsDisplay?.1 ?? Color(hex: "C4C4C4")
                showHsForm = hsDisplay != nil
                contractTypeText = contractText
                invoiceStatusText = invoiceText
                durationFromFormatted = durationFromFmt
                durationToFormatted = durationToFmt
                shiftStartTimeFormatted = startTimeFmt
                shiftEndTimeFormatted = endTimeFmt
                showShiftStartTime = showStart
                showShiftEndTime = showEnd
                isManager = isManagerSection
                self.isCaregiver = prefIsCaregiver
                self.isAdmin = prefIsAdmin
                self.isCustomer = prefIsCustomer
                editShiftButton = editShift
                isDeleteButton = deleteBtn
                isAllDayEditable = allDayEditable
                isAllDay = shiftData.isAllDay
                quotationButton = quotationBtn
                viewQuotationsButton = viewQuotationsBtn
                startButton = startBtn
                self.rejectButton = rejectBtn
                endButton = endBtn
                self.completeButton = completeBtn
                self.reviewsButton = reviewsBtn
                showFeedback = feedback
                self.reminderOptions = Self.defaultReminderOptions
                selectedReminderLabel = selectedLabel
                canEditReminder = canEdit
                canViewReminderOnly = canViewOnly
                hasReminderSet = hasReminder
                selectedManagerId = shiftData.userId?.isEmpty == true ? nil : shiftData.userId
                originalManagerId = shiftData.userId ?? ""

                if isManagerSection && !shiftData.caregiverId.isEmpty {
                    await loadContractorDetails(shiftData.caregiverId)
                }
                if prefIsAdmin {
                    if let userId = shiftData.userId, !userId.isEmpty {
                        await loadManagerDetails(userId)
                    }
                    await loadManagersList()
                }

            case .error(let msg, _):
                isLoading = false
                errorMessage = msg

            case .loading: break
            }
        }
    }

    private func loadContractorDetails(_ caregiverId: String) async {
        if case .success(let user) = await accountRepository.getUser(id: caregiverId) {
            contractorName = user.displayName
            contractorEmail = user.email
            contractorPhone = user.phoneNumber
        }
    }

    private func loadManagerDetails(_ userId: String) async {
        if case .success(let user) = await accountRepository.getUser(id: userId) {
            managerName = user.displayName
            managerEmail = user.email
            managerPhone = user.phoneNumber
        }
    }

    private func loadManagersList() async {
        if case .success(let data) = await accountRepository.getAllManagers() {
            managersList = data
        }
    }

    // MARK: - Actions

    func startShift() {
        guard let currentShift = shift else { return }
        isUpdating = true; errorMessage = nil
        Task { @MainActor in
            let userId = preferencesManager.userId
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let nowUtc = formatter.string(from: Date())
            var updated = currentShift
            updated.modifiedBy = userId
            updated.modifiedDate = nowUtc
            updated.shiftStartTime = nowUtc
            updated.statusId = 3
            switch await shiftRepository.updateShift(shiftDetail: updated) {
            case .success:
                isUpdating = false
                successMessage = "Shift started"
            case .error(let msg, _):
                isUpdating = false
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func endShift() {
        guard let currentShift = shift else { return }
        isUpdating = true; errorMessage = nil
        Task { @MainActor in
            let userId = preferencesManager.userId
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let nowUtc = formatter.string(from: Date())
            var updated = currentShift
            updated.modifiedBy = userId
            updated.modifiedDate = nowUtc
            updated.shiftEndTime = nowUtc
            updated.statusId = 4
            switch await shiftRepository.updateShift(shiftDetail: updated) {
            case .success:
                isUpdating = false
                successMessage = "Shift ended"
            case .error(let msg, _):
                isUpdating = false
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func rejectShift() {
        guard let currentShift = shift else { return }
        isUpdating = true; errorMessage = nil
        Task { @MainActor in
            let userId = preferencesManager.userId
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let nowUtc = formatter.string(from: Date())
            var updated = currentShift
            updated.modifiedBy = userId
            updated.modifiedDate = nowUtc
            updated.statusId = 5
            switch await shiftRepository.updateShift(shiftDetail: updated) {
            case .success:
                isUpdating = false
                successMessage = "Shift marked as not completed"
            case .error(let msg, _):
                isUpdating = false
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func deleteShift() {
        isUpdating = true; errorMessage = nil
        Task { @MainActor in
            switch await shiftRepository.deleteJob(id: shiftId) {
            case .success:
                isUpdating = false
                isDeleted = true
            case .error(let msg, _):
                isUpdating = false
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func completeShift() {
        navigateToFeedbackShiftId = shiftId
    }

    func onFeedbackNavigated() {
        navigateToFeedbackShiftId = nil
    }

    func viewReviews() {
        navigateToReviewsShiftId = shiftId
    }

    func onReviewsNavigated() {
        navigateToReviewsShiftId = nil
    }

    func updateIsAllDay(_ isAllDay: Bool) {
        self.isAllDay = isAllDay
    }

    func selectManager(_ managerId: String) {
        selectedManagerId = managerId
    }

    func updateShift() {
        guard let currentShift = shift else { return }
        isUpdating = true; errorMessage = nil
        Task { @MainActor in
            let currentUserId = preferencesManager.userId
            var updated = currentShift
            updated.isAllDay = isAllDay
            updated.modifiedBy = currentUserId
            if let managerId = selectedManagerId {
                updated.userId = managerId
            }
            switch await shiftRepository.updateShiftsExtraHour(shiftDetail: updated) {
            case .success:
                isUpdating = false
                successMessage = "Shift updated"
            case .error(let msg, _):
                isUpdating = false
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func selectReminder(_ label: String) {
        selectedReminderLabel = label
    }

    func addReminder() {
        guard let currentShift = shift else { return }
        guard let selectedOption = reminderOptions.first(where: { $0.label == selectedReminderLabel }) else { return }
        isUpdating = true; errorMessage = nil
        Task { @MainActor in
            var updated: ShiftDto
            if selectedOption.offsetMinutes == 0 {
                updated = currentShift
                updated.isReminderScheduled = false
                updated.reminderOffset = nil
                updated.reminderTime = nil
            } else {
                let reminderOffsetStr = minutesToTimeSpan(selectedOption.offsetMinutes)
                let reminderTime = calculateReminderTime(currentShift.durationFrom, selectedOption.offsetMinutes)
                updated = currentShift
                updated.isReminderScheduled = true
                updated.reminderOffset = reminderOffsetStr
                updated.reminderTime = reminderTime
            }
            switch await shiftRepository.addTaskReminder(shiftDetail: updated) {
            case .success(let result):
                isUpdating = false
                successMessage = "Reminder updated"
                hasReminderSet = result.isReminderScheduled
                shift = result
            case .error(let msg, _):
                isUpdating = false
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func clearError() { errorMessage = nil }
    func clearSuccessMessage() { successMessage = nil }

    // MARK: - Helpers

    private func getStatusDisplay(_ statusId: Int, _ hasQuotations: Bool) -> (String, Color) {
        switch statusId {
        case 1: return hasQuotations ? ("Quoted", Color(hex: "007AFF")) : ("Created", Color(hex: "FF9500"))
        case 2: return ("Accepted", Color(hex: "9D50DD"))
        case 3: return ("Started", Color(hex: "00C875"))
        case 4: return ("End", Color(hex: "74AFCC"))
        case 5: return ("Not Completed", Color(hex: "FF3B30"))
        case 6: return ("Completed", Color(hex: "FFCB00"))
        default: return ("Unknown", Color(hex: "C4C4C4"))
        }
    }

    private func getHsFormDisplay(_ hsForms: Int?) -> (String, Color)? {
        switch hsForms {
        case 0: return ("No H&S", Color(hex: "C4C4C4"))
        case 1: return ("SSSP", Color(hex: "007AFF"))
        case 2: return ("JSA", Color(hex: "FF9500"))
        case 3: return ("Take 5", Color(hex: "FF3B30"))
        case 4: return ("Done", Color(hex: "34C759"))
        case 5: return ("Missing H&S", Color(hex: "808080"))
        default: return nil
        }
    }

    private func getContractTypeText(_ contractType: Int?) -> String {
        switch contractType {
        case 1: return "To Be Confirmed"
        case 2: return "Full Contract"
        case 3: return "Supply Place And Finish"
        case 4: return "Place And Finish"
        case 5: return "Labour Supply"
        case 6: return "Box Place And Finish"
        case 7: return "Remedial"
        case 8: return "Supply Place Finish And Cut"
        case 9: return "Place Finish And Cut"
        case 10: return "Other Services"
        case 11: return "Meetings"
        default: return "Not Set"
        }
    }

    private func getInvoiceStatusText(_ invoiceStatus: Int?) -> String {
        switch invoiceStatus {
        case 1: return "Not Yet Created"
        case 2: return "To Be Invoiced"
        case 3: return "Invoice Drafted"
        case 4: return "Invoice Sent"
        default: return "Not Set"
        }
    }

    private func formatDateTime(_ dateStr: String) -> String {
        guard !dateStr.isEmpty else { return "" }
        for formatter in parseFormatters {
            if let parsed = formatter.date(from: dateStr.trimmingCharacters(in: .whitespaces)) {
                return displayDateFormat.string(from: parsed)
            }
        }
        // Fallback: trim fractional seconds
        let trimmed = dateStr.replacingOccurrences(of: #"\.\d+$"#, with: "", options: .regularExpression)
        if let parsed = parseFormatters[0].date(from: trimmed) {
            return displayDateFormat.string(from: parsed)
        }
        return dateStr
    }

    private func resolveReminderLabel(_ reminderOffset: String?) -> String {
        guard let offset = reminderOffset, !offset.isEmpty else { return "None" }
        let totalMinutes = parseTimeSpanToMinutes(offset)
        return reminderOptions.first { $0.offsetMinutes == totalMinutes }?.label ?? "None"
    }

    private func parseTimeSpanToMinutes(_ timeSpan: String) -> Int64 {
        let cleaned = timeSpan.trimmingCharacters(in: .whitespaces)
        var days: Int64 = 0
        var timePart = cleaned

        if cleaned.contains(".") {
            let dotIndex = cleaned.firstIndex(of: ".")!
            let beforeDot = String(cleaned[cleaned.startIndex..<dotIndex])
            let afterDot = String(cleaned[cleaned.index(after: dotIndex)...])

            if beforeDot.contains(":") {
                timePart = beforeDot
            } else {
                days = Int64(beforeDot) ?? 0
                timePart = afterDot
                if let fracIndex = timePart.firstIndex(of: ".") {
                    timePart = String(timePart[timePart.startIndex..<fracIndex])
                }
            }
        }

        let parts = timePart.split(separator: ":")
        let hours = Int64(parts.count > 0 ? String(parts[0]) : "0") ?? 0
        let minutes = Int64(parts.count > 1 ? String(parts[1]) : "0") ?? 0

        return days * 1440 + hours * 60 + minutes
    }

    private func minutesToTimeSpan(_ totalMinutes: Int64) -> String {
        let days = totalMinutes / 1440
        let remaining = totalMinutes % 1440
        let hours = remaining / 60
        let mins = remaining % 60
        if days > 0 {
            return String(format: "%d.%02d:%02d:00", days, hours, mins)
        }
        return String(format: "%02d:%02d:00", hours, mins)
    }

    private func calculateReminderTime(_ durationFrom: String, _ offsetMinutes: Int64) -> String? {
        for formatter in parseFormatters {
            if let parsed = formatter.date(from: durationFrom.trimmingCharacters(in: .whitespaces)) {
                let reminderDt = Calendar.current.date(byAdding: .minute, value: -Int(offsetMinutes), to: parsed)!
                let isoFormatter = DateFormatter()
                isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                isoFormatter.locale = Locale(identifier: "en_US_POSIX")
                return isoFormatter.string(from: reminderDt)
            }
        }
        return nil
    }
}
