import Foundation
import SwiftUI

// MARK: - Data Models

struct JobRowItem: Identifiable {
    var shift: ShiftDto
    var statusDisplayText: String
    var statusColor: Color
    var invoiceDisplayText: String
    var invoiceColor: Color
    var contractTypeDisplayText: String
    var contractTypeColor: Color
    var hsFormText: String
    var hsFormColor: Color
    var hasQuotations: Bool = false
    var subItems: [ShiftSubItemDto] = []
    var isExpanded: Bool = false
    var isOwner: Bool = false
    var isAddSubItem: Bool = false
    var newSubItemName: String = ""

    var id: Int { shift.id }
}

struct MLFilterColumnOption: Identifiable {
    let id = UUID()
    let displayName: String
    let propertyName: String
    let columnType: FilterColumnType
    let icon: String
    let availableConditions: [String]

    init(_ displayName: String, _ propertyName: String,
         _ columnType: FilterColumnType = .itemColumn,
         _ icon: String = "",
         _ availableConditions: [String] = []) {
        self.displayName = displayName
        self.propertyName = propertyName
        self.columnType = columnType
        self.icon = icon
        self.availableConditions = availableConditions
    }
}

struct MLFilterRow: Identifiable {
    let id: Int64
    var selectedColumn: MLFilterColumnOption? = nil
    var selectedCondition: String = ""
    var value: String = ""
    var isApplied: Bool = false

    var isComplete: Bool {
        selectedColumn != nil && !selectedCondition.isEmpty &&
        (!value.isEmpty || selectedCondition == "is empty" || selectedCondition == "is not empty")
    }

    init(id: Int64 = Int64(Date().timeIntervalSince1970 * 1_000_000_000) + Int64.random(in: 0...999999),
         selectedColumn: MLFilterColumnOption? = nil,
         selectedCondition: String = "",
         value: String = "",
         isApplied: Bool = false) {
        self.id = id
        self.selectedColumn = selectedColumn
        self.selectedCondition = selectedCondition
        self.value = value
        self.isApplied = isApplied
    }
}

struct KanbanColumn: Identifiable {
    let id = UUID()
    let title: String
    let headerColor: Color
    let items: [JobRowItem]
}

// Edit dialog types
enum EditDialogType {
    case none, textEditor, dateTimePicker, contractTypePicker, invoiceStatusPicker,
         hsFormStatusPicker, subItemHSPicker, subItemStatusPicker, clientPicker,
         addressSearch, subItemDatePicker, deleteSubItem
}

struct EditDialogState {
    var type: EditDialogType = .none
    var title: String = ""
    var fieldName: String = ""
    var textValue: String = ""
    var selectedShiftId: Int = 0
    var selectedSubItemId: Int = 0
    var selectedDate: Date = Date()
    var selectedHour: Int = 0
    var selectedMinute: Int = 0
}

struct StatusOption: Identifiable {
    let id = UUID()
    let name: String
    let value: Int
    let color: Color
}

// MARK: - ViewModel

@Observable
class MainLeadsJobsViewModel {
    var isLoading: Bool = true
    var isLoadingMore: Bool = false
    var jobs: [JobRowItem] = []
    var currentMonth: Int
    var currentYear: Int
    var monthDisplayText: String = ""
    var sortColumn: String = ""
    var sortAscending: Bool = true
    var errorMessage: String? = nil
    var successMessage: String? = nil
    // Role flags
    var isOwner: Bool = false
    var isCaregiver: Bool = false
    // View mode
    var selectedViewMode: String = "Main Table"
    var isListView: Bool = true
    var kanbanColumns: [KanbanColumn] = []
    // Filter
    var filterColumns: [MLFilterColumnOption] = []
    var pendingFilters: [MLFilterRow] = []
    var activeFilters: [MLFilterRow] = []
    var filterStatusText: String = "Showing all of 0 projects"
    var hasActiveFilters: Bool = false
    var hasPendingFilters: Bool = false
    var hasFiltersToApply: Bool = false
    var showEmptyState: Bool = true
    // Edit dialog
    var editDialog: EditDialogState = EditDialogState()
    // Address search
    var addressSearchText: String = ""
    var placeSuggestions: [PlacePrediction] = []
    // Clients
    var clients: [ClientDto] = []
    // Pagination
    var canLoadMore: Bool = true

    private var originalJobs: [JobRowItem] = []
    private var currentSkip: Int = 0
    private let pageSize: Int = 20

    private let shiftRepository: ShiftRepository
    private let clientRepository: ClientRepository
    private let preferencesManager: PreferencesManager
    private let googlePlacesService: GooglePlacesService
    private var hasLoaded = false

    init(
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        clientRepository: ClientRepository = DIContainer.shared.clientRepository,
        preferencesManager: PreferencesManager = PreferencesManager.shared,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService
    ) {
        self.shiftRepository = shiftRepository
        self.clientRepository = clientRepository
        self.preferencesManager = preferencesManager
        self.googlePlacesService = googlePlacesService

        let now = Date()
        let calendar = Calendar.current
        self.currentMonth = calendar.component(.month, from: now)
        self.currentYear = calendar.component(.year, from: now)

        filterColumns = Self.buildFilterColumns()
        updateMonthDisplay()
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadClients()
        loadJobs()
    }

    private func loadClients() {
        Task { @MainActor in
            let result = await clientRepository.getAllClients()
            if case .success(let allClients) = result {
                let selectClient = ClientDto(id: 0, name: "Select Client")
                clients = [selectClient] + allClients
            }
        }
    }

    private func updateMonthDisplay() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let monthName = formatter.monthSymbols[currentMonth - 1]
        monthDisplayText = "\(monthName) \(currentYear)"
    }

    func previousMonth() {
        currentMonth -= 1
        if currentMonth < 1 { currentMonth = 12; currentYear -= 1 }
        updateMonthDisplay()
        loadJobs()
    }

    func nextMonth() {
        currentMonth += 1
        if currentMonth > 12 { currentMonth = 1; currentYear += 1 }
        updateMonthDisplay()
        loadJobs()
    }

    // MARK: - Load Jobs (Paginated)

    func loadJobs() {
        currentSkip = 0
        isLoading = true
        errorMessage = nil
        canLoadMore = true

        Task { @MainActor in
            let isMgr = preferencesManager.isManager
            let isCg = preferencesManager.isCaregiver
            let isAdm = preferencesManager.isAdmin
            let userId = preferencesManager.userId
            let owner = isMgr || isAdm

            let result = await fetchPage(isAdmin: isAdm, isCaregiver: isCg, userId: userId, month: currentMonth, year: currentYear, skip: 0, take: pageSize)

            switch result {
            case .success(let shifts):
                let jobRows = mapShiftsToRows(shifts, isOwner: owner)
                originalJobs = jobRows
                currentSkip = jobRows.count
                let moreAvailable = shifts.count >= pageSize
                let sorted = sortJobs(jobRows, column: sortColumn, ascending: sortAscending)
                isLoading = false
                jobs = sorted
                isOwner = owner
                isCaregiver = isCg
                canLoadMore = moreAvailable
                applyFiltersToData()
                buildKanban()
                updateFilterStatus()
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    func loadMore() {
        guard !isLoadingMore, canLoadMore, !isLoading else { return }
        isLoadingMore = true
        let skipAtStart = currentSkip

        Task { @MainActor in
            let isMgr = preferencesManager.isManager
            let isCg = preferencesManager.isCaregiver
            let isAdm = preferencesManager.isAdmin
            let userId = preferencesManager.userId
            let owner = isMgr || isAdm

            let result = await fetchPage(isAdmin: isAdm, isCaregiver: isCg, userId: userId, month: currentMonth, year: currentYear, skip: skipAtStart, take: pageSize)

            switch result {
            case .success(let shifts):
                if currentSkip != skipAtStart {
                    isLoadingMore = false
                    return
                }
                let newRows = mapShiftsToRows(shifts, isOwner: owner)
                originalJobs += newRows
                currentSkip += newRows.count
                let moreAvailable = shifts.count >= pageSize
                let sorted = sortJobs(originalJobs, column: sortColumn, ascending: sortAscending)
                isLoadingMore = false
                jobs = sorted
                canLoadMore = moreAvailable
                applyFiltersToData()
                buildKanban()
                updateFilterStatus()
            case .error(let message, _):
                isLoadingMore = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    private func fetchPage(isAdmin: Bool, isCaregiver: Bool, userId: String,
                           month: Int, year: Int, skip: Int, take: Int) async -> ApiResult<[ShiftDto]> {
        if isAdmin {
            return await shiftRepository.getMonthlyJobsByAdmin(month: month, year: year, skip: skip, take: take)
        } else if isCaregiver {
            return await shiftRepository.getMonthlyJobsByCaregiverId(caregiverId: userId, month: month, year: year, skip: skip, take: take)
        } else {
            return await shiftRepository.getMonthlyJobsByUserId(userId: userId, month: month, year: year, skip: skip, take: take)
        }
    }

    private func mapShiftsToRows(_ shifts: [ShiftDto], isOwner: Bool) -> [JobRowItem] {
        return shifts.map { shift in
            let hasQuotations = !(shift.jobQuotations?.isEmpty ?? true) &&
                shift.statusId == ShiftStatus.created.rawValue &&
                isOwner
            var s = shift
            s.hasQuotations = hasQuotations
            return JobRowItem(
                shift: s,
                statusDisplayText: Self.getStatusText(shift.statusId, hasQuotations: hasQuotations),
                statusColor: Self.getStatusColor(shift.statusId, hasQuotations: hasQuotations),
                invoiceDisplayText: Self.getInvoiceText(shift.invoiceStatus),
                invoiceColor: Self.getInvoiceColor(shift.invoiceStatus),
                contractTypeDisplayText: Self.getContractTypeText(shift.contractType),
                contractTypeColor: Self.getContractTypeColor(shift.contractType),
                hsFormText: Self.getHSFormText(shift.hsForms),
                hsFormColor: Self.getHSFormColor(shift.hsForms),
                subItems: shift.shiftSubItems ?? [],
                isOwner: isOwner,
                isAddSubItem: isOwner
            )
        }
    }

    // MARK: - Toggle Expand

    func toggleExpanded(_ shiftId: Int) {
        func toggle(_ row: JobRowItem) -> JobRowItem {
            if row.shift.id == shiftId {
                var r = row
                r.isExpanded = !r.isExpanded
                return r
            }
            return row
        }
        originalJobs = originalJobs.map { toggle($0) }
        jobs = jobs.map { toggle($0) }
    }

    // MARK: - Sorting

    func sortBy(_ column: String) {
        let ascending = (sortColumn == column) ? !sortAscending : true
        sortColumn = column
        sortAscending = ascending
        jobs = sortJobs(jobs, column: column, ascending: ascending)
    }

    private func sortJobs(_ jobs: [JobRowItem], column: String, ascending: Bool) -> [JobRowItem] {
        guard !column.isEmpty else { return jobs }
        let sorted = jobs.sorted { a, b in
            let cmp: Bool
            switch column {
            case "ProjectName": cmp = a.shift.projectName.lowercased() < b.shift.projectName.lowercased()
            case "ClientName": cmp = (a.shift.clientName ?? "").lowercased() < (b.shift.clientName ?? "").lowercased()
            case "Address": cmp = a.shift.address.lowercased() < b.shift.address.lowercased()
            case "DurationFromString": cmp = a.shift.durationFrom < b.shift.durationFrom
            case "DurationToString": cmp = a.shift.durationTo < b.shift.durationTo
            case "ContractType": cmp = a.contractTypeDisplayText.lowercased() < b.contractTypeDisplayText.lowercased()
            case "InvoiceStatus": cmp = a.invoiceDisplayText.lowercased() < b.invoiceDisplayText.lowercased()
            case "HSForm": cmp = (a.shift.hsForms ?? 0) < (b.shift.hsForms ?? 0)
            case "FinalMeasure": cmp = a.shift.finalMeasure.lowercased() < b.shift.finalMeasure.lowercased()
            case "Instructions": cmp = a.shift.instructions.lowercased() < b.shift.instructions.lowercased()
            case "Amount": cmp = (a.shift.amount ?? 0) < (b.shift.amount ?? 0)
            case "AcceptedQuoteAmount": cmp = (a.shift.acceptedQuoteAmount ?? 0) < (b.shift.acceptedQuoteAmount ?? 0)
            case "StatusMessage": cmp = a.statusDisplayText.lowercased() < b.statusDisplayText.lowercased()
            default: cmp = a.shift.projectName.lowercased() < b.shift.projectName.lowercased()
            }
            return ascending ? cmp : !cmp
        }
        return sorted
    }

    // MARK: - View Mode

    func setViewMode(_ mode: String) {
        selectedViewMode = mode
        isListView = mode == "Main Table"
        if mode == "Kanban" && canLoadMore {
            loadAllRemaining()
        }
    }

    private func loadAllRemaining() {
        Task { @MainActor in
            let isMgr = preferencesManager.isManager
            let isCg = preferencesManager.isCaregiver
            let isAdm = preferencesManager.isAdmin
            let userId = preferencesManager.userId
            let owner = isMgr || isAdm

            while canLoadMore {
                let result = await fetchPage(isAdmin: isAdm, isCaregiver: isCg, userId: userId, month: currentMonth, year: currentYear, skip: currentSkip, take: pageSize)
                switch result {
                case .success(let shifts):
                    if shifts.isEmpty {
                        canLoadMore = false
                        break
                    }
                    let newRows = mapShiftsToRows(shifts, isOwner: owner)
                    originalJobs += newRows
                    currentSkip += newRows.count
                    canLoadMore = shifts.count >= pageSize
                    let sorted = sortJobs(originalJobs, column: sortColumn, ascending: sortAscending)
                    jobs = sorted
                    applyFiltersToData()
                    buildKanban()
                    updateFilterStatus()
                case .error:
                    canLoadMore = false
                case .loading:
                    canLoadMore = false
                }
            }
        }
    }

    private func buildKanban() {
        guard !jobs.isEmpty else {
            kanbanColumns = []
            return
        }
        let grouped = Dictionary(grouping: jobs) { $0.shift.contractType ?? 0 }
        let columns = grouped.keys.sorted().compactMap { key -> KanbanColumn? in
            guard let groupJobs = grouped[key], let first = groupJobs.first else { return nil }
            return KanbanColumn(
                title: "\(first.contractTypeDisplayText) / \(groupJobs.count)",
                headerColor: first.contractTypeColor,
                items: groupJobs
            )
        }
        kanbanColumns = columns
    }

    // MARK: - Inline Edit Dialogs

    func editProjectName(_ shiftId: Int) {
        guard !isCaregiver else { return }
        guard let job = findJob(shiftId) else { return }
        editDialog = EditDialogState(
            type: .textEditor, title: "Project Name",
            fieldName: "ProjectName", textValue: job.shift.projectName,
            selectedShiftId: shiftId
        )
    }

    func editFinalMeasure(_ shiftId: Int) {
        guard !isCaregiver else { return }
        guard let job = findJob(shiftId) else { return }
        editDialog = EditDialogState(
            type: .textEditor, title: "Final Measure",
            fieldName: "FinalMeasure", textValue: job.shift.finalMeasure,
            selectedShiftId: shiftId
        )
    }

    func editJobDescription(_ shiftId: Int) {
        guard !isCaregiver else { return }
        guard let job = findJob(shiftId) else { return }
        editDialog = EditDialogState(
            type: .textEditor, title: "Job Description",
            fieldName: "Instructions", textValue: job.shift.instructions,
            selectedShiftId: shiftId
        )
    }

    func editDurationFrom(_ shiftId: Int) {
        guard !isCaregiver else { return }
        guard let job = findJob(shiftId) else { return }
        let dt = parseDateTimeOrNow(job.shift.durationFrom)
        let calendar = Calendar.current
        editDialog = EditDialogState(
            type: .dateTimePicker, title: "Duration From",
            fieldName: "DurationFrom", selectedShiftId: shiftId,
            selectedDate: dt, selectedHour: calendar.component(.hour, from: dt),
            selectedMinute: calendar.component(.minute, from: dt)
        )
    }

    func editDurationTo(_ shiftId: Int) {
        guard !isCaregiver else { return }
        guard let job = findJob(shiftId) else { return }
        let dt = parseDateTimeOrNow(job.shift.durationTo)
        let calendar = Calendar.current
        editDialog = EditDialogState(
            type: .dateTimePicker, title: "Duration To",
            fieldName: "DurationTo", selectedShiftId: shiftId,
            selectedDate: dt, selectedHour: calendar.component(.hour, from: dt),
            selectedMinute: calendar.component(.minute, from: dt)
        )
    }

    func editContractType(_ shiftId: Int) {
        guard !isCaregiver else { return }
        editDialog = EditDialogState(type: .contractTypePicker, title: "Contract Type", selectedShiftId: shiftId)
    }

    func editInvoiceStatus(_ shiftId: Int) {
        guard !isCaregiver else { return }
        editDialog = EditDialogState(type: .invoiceStatusPicker, title: "Invoice Status", selectedShiftId: shiftId)
    }

    func editHSFormStatus(_ shiftId: Int) {
        guard !isCaregiver else { return }
        editDialog = EditDialogState(type: .hsFormStatusPicker, title: "H&S Form Status", selectedShiftId: shiftId)
    }

    func editSubItemHSStatus(_ subItemId: Int) {
        guard !isCaregiver else { return }
        editDialog = EditDialogState(type: .subItemHSPicker, title: "H&S Status", selectedSubItemId: subItemId)
    }

    func editSubItemStatus(_ subItemId: Int) {
        guard !isCaregiver else { return }
        editDialog = EditDialogState(type: .subItemStatusPicker, title: "Sub-Item Status", selectedSubItemId: subItemId)
    }

    func editAddress(_ shiftId: Int) {
        guard !isCaregiver else { return }
        guard let job = findJob(shiftId) else { return }
        editDialog = EditDialogState(type: .addressSearch, title: "Search Address", selectedShiftId: shiftId)
        addressSearchText = job.shift.address
        placeSuggestions = []
    }

    func editClient(_ shiftId: Int) {
        guard !isCaregiver else { return }
        editDialog = EditDialogState(type: .clientPicker, title: "Select Client", selectedShiftId: shiftId)
    }

    func confirmDeleteSubItem(_ subItemId: Int) {
        editDialog = EditDialogState(type: .deleteSubItem, title: "Delete Sub-Item", selectedSubItemId: subItemId)
    }

    var deleteSubItemName: String {
        guard let subItem = findSubItem(editDialog.selectedSubItemId) else { return "" }
        return subItem.subitem
    }

    func editSubItemDateStarted(shiftId: Int, subItemId: Int) {
        guard !isCaregiver else { return }
        guard let subItem = findSubItem(subItemId) else { return }
        let calendar = Calendar.current
        var date = Date()
        var hour = 12
        var minute = 0
        if let dateStr = subItem.dateStarted, !dateStr.isEmpty {
            let dt = parseDateTimeOrNow(dateStr)
            date = dt
            hour = calendar.component(.hour, from: dt)
            minute = calendar.component(.minute, from: dt)
        }
        editDialog = EditDialogState(
            type: .subItemDatePicker, title: "Date Started",
            selectedShiftId: shiftId, selectedSubItemId: subItemId,
            selectedDate: date, selectedHour: hour, selectedMinute: minute
        )
    }

    // MARK: - Address Search

    func onAddressSearchChange(_ text: String) {
        addressSearchText = text
        if text.count >= 3 {
            Task { @MainActor in
                let predictions = await googlePlacesService.getPlacesByText(searchText: text)
                placeSuggestions = predictions
            }
        } else {
            placeSuggestions = []
        }
    }

    func onPlaceSelected(_ prediction: PlacePrediction) {
        Task { @MainActor in
            if let place = await googlePlacesService.getPlaceDetails(placeId: prediction.placeId) {
                saveAddress(place.address, latitude: place.latitude, longitude: place.longitude)
            }
        }
    }

    private func saveAddress(_ address: String, latitude: Double, longitude: Double) {
        guard let job = findJob(editDialog.selectedShiftId) else { return }
        var updatedShift = job.shift
        updatedShift.address = address
        updatedShift.latitude = latitude
        updatedShift.longitude = longitude
        dismissEditDialog()
        updateShift(updatedShift)
    }

    // MARK: - Save Actions

    func selectClient(_ clientId: Int, clientName: String) {
        guard let job = findJob(editDialog.selectedShiftId) else { return }
        var updatedShift = job.shift
        updatedShift.clientId = clientId > 0 ? clientId : nil
        updatedShift.clientName = clientId > 0 ? clientName : ""
        dismissEditDialog()
        updateShift(updatedShift)
    }

    func saveSubItemDate(date: Date, hour: Int, minute: Int) {
        guard let subItem = findSubItem(editDialog.selectedSubItemId) else { return }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        if let dt = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let dateTimeStr = formatter.string(from: dt)
            var updated = subItem
            updated.dateStarted = dateTimeStr
            dismissEditDialog()
            updateSubItem(updated)
        }
    }

    func updateEditDialogText(_ text: String) {
        editDialog.textValue = text
    }

    func updateEditDialogDate(_ date: Date) {
        editDialog.selectedDate = date
    }

    func updateEditDialogTime(hour: Int, minute: Int) {
        editDialog.selectedHour = hour
        editDialog.selectedMinute = minute
    }

    func dismissEditDialog() {
        editDialog = EditDialogState()
        placeSuggestions = []
    }

    func saveTextEdit() {
        guard let job = findJob(editDialog.selectedShiftId) else { return }
        var updatedShift = job.shift
        switch editDialog.fieldName {
        case "ProjectName": updatedShift.projectName = editDialog.textValue
        case "FinalMeasure": updatedShift.finalMeasure = editDialog.textValue
        case "Instructions": updatedShift.instructions = editDialog.textValue
        default: return
        }
        dismissEditDialog()
        updateShift(updatedShift)
    }

    func saveDateTimeEdit() {
        guard let job = findJob(editDialog.selectedShiftId) else { return }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: editDialog.selectedDate)
        components.hour = editDialog.selectedHour
        components.minute = editDialog.selectedMinute
        components.second = 0
        guard let dt = calendar.date(from: components) else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let formatted = formatter.string(from: dt)

        var updatedShift = job.shift
        switch editDialog.fieldName {
        case "DurationFrom": updatedShift.durationFrom = formatted
        case "DurationTo": updatedShift.durationTo = formatted
        default: return
        }
        dismissEditDialog()
        updateShift(updatedShift)
    }

    func selectContractType(_ value: Int) {
        guard let job = findJob(editDialog.selectedShiftId) else { return }
        var updatedShift = job.shift
        updatedShift.contractType = value
        dismissEditDialog()
        updateShift(updatedShift)
    }

    func selectInvoiceStatus(_ value: Int) {
        guard let job = findJob(editDialog.selectedShiftId) else { return }
        var updatedShift = job.shift
        updatedShift.invoiceStatus = value
        dismissEditDialog()
        updateShift(updatedShift)
    }

    func selectHSFormStatus(_ value: Int) {
        guard let job = findJob(editDialog.selectedShiftId) else { return }
        var updatedShift = job.shift
        updatedShift.hsForms = value
        dismissEditDialog()
        updateShift(updatedShift)
    }

    func selectSubItemHSStatus(_ value: Int) {
        guard var subItem = findSubItem(editDialog.selectedSubItemId) else { return }
        subItem.hsRequired = value
        dismissEditDialog()
        updateSubItem(subItem)
    }

    func selectSubItemStatus(_ value: Int) {
        guard var subItem = findSubItem(editDialog.selectedSubItemId) else { return }
        subItem.status = value
        dismissEditDialog()
        updateSubItem(subItem)
    }

    private func updateShift(_ shift: ShiftDto) {
        Task { @MainActor in
            let userId = preferencesManager.userId
            var updated = shift
            updated.modifiedBy = userId
            let result = await shiftRepository.updateShift(shiftDetail: updated)
            switch result {
            case .success(let returnedShift):
                updateShiftInPlace(returnedShift)
            case .error(let message, _):
                errorMessage = message ?? "Failed to update"
            case .loading: break
            }
        }
    }

    private func updateShiftInPlace(_ updatedShift: ShiftDto) {
        // Enrich clientName from local clients list when API returns null
        var enrichedShift = updatedShift
        if (enrichedShift.clientName ?? "").isEmpty, let clientId = enrichedShift.clientId, clientId > 0 {
            if let clientName = clients.first(where: { $0.id == clientId })?.name, !clientName.isEmpty {
                enrichedShift.clientName = clientName
            }
        }

        let hasQuotations = !(enrichedShift.jobQuotations?.isEmpty ?? true) &&
            enrichedShift.statusId == ShiftStatus.created.rawValue &&
            isOwner
        enrichedShift.hasQuotations = hasQuotations

        func updateRow(_ row: JobRowItem) -> JobRowItem {
            guard row.shift.id == enrichedShift.id else { return row }
            var s = enrichedShift
            s.shiftSubItems = row.shift.shiftSubItems
            return JobRowItem(
                shift: s,
                statusDisplayText: Self.getStatusText(enrichedShift.statusId, hasQuotations: hasQuotations),
                statusColor: Self.getStatusColor(enrichedShift.statusId, hasQuotations: hasQuotations),
                invoiceDisplayText: Self.getInvoiceText(enrichedShift.invoiceStatus),
                invoiceColor: Self.getInvoiceColor(enrichedShift.invoiceStatus),
                contractTypeDisplayText: Self.getContractTypeText(enrichedShift.contractType),
                contractTypeColor: Self.getContractTypeColor(enrichedShift.contractType),
                hsFormText: Self.getHSFormText(enrichedShift.hsForms),
                hsFormColor: Self.getHSFormColor(enrichedShift.hsForms),
                subItems: row.subItems,
                isExpanded: row.isExpanded,
                isOwner: row.isOwner,
                isAddSubItem: row.isAddSubItem,
                newSubItemName: row.newSubItemName
            )
        }

        originalJobs = originalJobs.map { updateRow($0) }
        jobs = jobs.map { updateRow($0) }
        buildKanban()
    }

    private func updateSubItem(_ subItem: ShiftSubItemDto) {
        Task { @MainActor in
            let result = await shiftRepository.editSubItems(subItem: subItem)
            switch result {
            case .success(let returnedSubItem):
                updateSubItemInPlace(returnedSubItem)
            case .error(let message, _):
                errorMessage = message ?? "Failed to update sub-item"
            case .loading: break
            }
        }
    }

    private func updateSubItemInPlace(_ updatedSubItem: ShiftSubItemDto) {
        func updateRow(_ row: JobRowItem) -> JobRowItem {
            guard row.shift.id == updatedSubItem.shiftId else { return row }
            let updatedSubItems = row.subItems.map { sub in
                sub.id == updatedSubItem.id ? updatedSubItem : sub
            }
            var s = row.shift
            s.shiftSubItems = updatedSubItems
            return JobRowItem(
                shift: s, statusDisplayText: row.statusDisplayText,
                statusColor: row.statusColor, invoiceDisplayText: row.invoiceDisplayText,
                invoiceColor: row.invoiceColor, contractTypeDisplayText: row.contractTypeDisplayText,
                contractTypeColor: row.contractTypeColor, hsFormText: row.hsFormText,
                hsFormColor: row.hsFormColor, subItems: updatedSubItems,
                isExpanded: row.isExpanded, isOwner: row.isOwner,
                isAddSubItem: row.isAddSubItem, newSubItemName: row.newSubItemName
            )
        }
        originalJobs = originalJobs.map { updateRow($0) }
        jobs = jobs.map { updateRow($0) }
    }

    // MARK: - Sub-item Add / Delete

    func updateNewSubItemName(shiftId: Int, name: String) {
        jobs = jobs.map { row in
            if row.shift.id == shiftId {
                var r = row
                r.newSubItemName = name
                return r
            }
            return row
        }
    }

    func addNewSubItem(_ shiftId: Int) {
        guard let job = findJob(shiftId) else { return }
        let name = job.newSubItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            errorMessage = "Please enter a sub-item name."
            return
        }

        Task { @MainActor in
            let userId = preferencesManager.userId
            let newSubItem = ShiftSubItemDto(
                shiftId: shiftId,
                subitem: name,
                hsRequired: HSRequiredStatus.noHS.rawValue,
                status: 0,
                createdBy: userId
            )
            let result = await shiftRepository.addSubItems(subItem: newSubItem)
            switch result {
            case .success(let addedSubItem):
                func addToRow(_ row: JobRowItem) -> JobRowItem {
                    guard row.shift.id == shiftId else { return row }
                    let updatedSubItems = row.subItems + [addedSubItem]
                    var s = row.shift
                    s.shiftSubItems = updatedSubItems
                    return JobRowItem(
                        shift: s, statusDisplayText: row.statusDisplayText,
                        statusColor: row.statusColor, invoiceDisplayText: row.invoiceDisplayText,
                        invoiceColor: row.invoiceColor, contractTypeDisplayText: row.contractTypeDisplayText,
                        contractTypeColor: row.contractTypeColor, hsFormText: row.hsFormText,
                        hsFormColor: row.hsFormColor, subItems: updatedSubItems,
                        isExpanded: row.isExpanded, isOwner: row.isOwner,
                        isAddSubItem: row.isAddSubItem, newSubItemName: ""
                    )
                }
                originalJobs = originalJobs.map { addToRow($0) }
                successMessage = "Sub-item added successfully."
                jobs = jobs.map { addToRow($0) }
            case .error(let message, _):
                errorMessage = message ?? "Failed to add sub-item."
            case .loading: break
            }
        }
    }

    func deleteSubItem(_ subItemId: Int) {
        Task { @MainActor in
            let result = await shiftRepository.deleteSubItem(id: subItemId)
            switch result {
            case .success:
                func removeFromRow(_ row: JobRowItem) -> JobRowItem {
                    let updatedSubItems = row.subItems.filter { $0.id != subItemId }
                    guard updatedSubItems.count != row.subItems.count else { return row }
                    var s = row.shift
                    s.shiftSubItems = updatedSubItems
                    return JobRowItem(
                        shift: s, statusDisplayText: row.statusDisplayText,
                        statusColor: row.statusColor, invoiceDisplayText: row.invoiceDisplayText,
                        invoiceColor: row.invoiceColor, contractTypeDisplayText: row.contractTypeDisplayText,
                        contractTypeColor: row.contractTypeColor, hsFormText: row.hsFormText,
                        hsFormColor: row.hsFormColor, subItems: updatedSubItems,
                        isExpanded: row.isExpanded, isOwner: row.isOwner,
                        isAddSubItem: row.isAddSubItem, newSubItemName: row.newSubItemName
                    )
                }
                originalJobs = originalJobs.map { removeFromRow($0) }
                successMessage = "Sub-item deleted."
                jobs = jobs.map { removeFromRow($0) }
            case .error(let message, _):
                errorMessage = message ?? "Failed to delete sub-item."
            case .loading: break
            }
        }
    }

    // MARK: - Filter System

    private static func buildFilterColumns() -> [MLFilterColumnOption] {
        var columns: [MLFilterColumnOption] = []
        columns.append(MLFilterColumnOption("Item columns", "", .itemColumn, "", []))
        let itemCols: [(String, String)] = [
            ("Project Name", "ProjectName"),
            ("Client Name", "ClientName"),
            ("Address", "Address"),
            ("Duration From", "DurationFromString"),
            ("Duration To", "DurationToString"),
            ("Contract Type", "ContractTypeText"),
            ("Invoice Status", "InvoiceStatusText"),
            ("H&S Forms", "HSForms"),
            ("Final Measure", "FinalMeasure"),
            ("Job Description", "Instructions"),
            ("Status", "StatusMessage")
        ]
        for (display, prop) in itemCols {
            columns.append(MLFilterColumnOption(display, prop, .itemColumn, "", getConditions(display)))
        }
        columns.append(MLFilterColumnOption("Subitem columns", "", .subItemColumn, "", []))
        let subCols: [(String, String)] = [
            ("Sub Item", "SubItem.Subitem"),
            ("H&S Required", "SubItem.HSRequiredText"),
            ("Status", "SubItem.StatusText"),
            ("Date Started", "SubItem.DateStartedString"),
            ("Completed", "SubItem.DateCompletedString")
        ]
        for (display, prop) in subCols {
            columns.append(MLFilterColumnOption(display, prop, .subItemColumn, "", getConditions(display)))
        }
        return columns
    }

    private static func getConditions(_ colName: String) -> [String] {
        let lower = colName.lowercased()
        if lower.contains("date") || lower.contains("duration") {
            return ["contains", "doesn't contain", "is", "is not", "is empty", "is not empty"]
        } else if lower.contains("status") || lower.contains("type") || lower.contains("h&s forms") {
            return ["is", "is not", "contains", "doesn't contain"]
        } else if lower.contains("h&s") && lower.contains("required") {
            return ["is", "is not"]
        } else {
            return ["contains", "doesn't contain", "starts with", "is", "is not", "is empty", "is not empty"]
        }
    }

    func addFilter() {
        let filterableCols = filterColumns.filter { !$0.propertyName.isEmpty }
        guard !filterableCols.isEmpty else { return }
        let newFilter = MLFilterRow(selectedColumn: filterableCols.first)
        pendingFilters.append(newFilter)
        updateFilterStatus()
    }

    func updatePendingFilterColumn(filterId: Int64, column: MLFilterColumnOption) {
        pendingFilters = pendingFilters.map {
            if $0.id == filterId {
                var f = $0
                f.selectedColumn = column
                f.selectedCondition = ""
                f.value = ""
                return f
            }
            return $0
        }
        updateFilterStatus()
    }

    func updatePendingFilterCondition(filterId: Int64, condition: String) {
        pendingFilters = pendingFilters.map {
            if $0.id == filterId {
                var f = $0
                f.selectedCondition = condition
                return f
            }
            return $0
        }
        updateFilterStatus()
    }

    func updatePendingFilterValue(filterId: Int64, value: String) {
        pendingFilters = pendingFilters.map {
            if $0.id == filterId {
                var f = $0
                f.value = value
                return f
            }
            return $0
        }
        updateFilterStatus()
    }

    func removePendingFilter(filterId: Int64) {
        pendingFilters = pendingFilters.filter { $0.id != filterId }
        activeFilters = activeFilters.filter { $0.id != filterId }
        applyFiltersToData()
        updateFilterStatus()
    }

    func applyFilters() {
        let complete = pendingFilters.filter { $0.isComplete }
        guard !complete.isEmpty else { return }
        activeFilters += complete.map { var f = $0; f.isApplied = true; return f }
        pendingFilters = pendingFilters.filter { !$0.isComplete }
        applyFiltersToData()
        updateFilterStatus()
    }

    func clearAllFilters() {
        pendingFilters = []
        activeFilters = []
        applyFiltersToData()
        updateFilterStatus()
    }

    private func applyFiltersToData() {
        if activeFilters.isEmpty {
            jobs = sortJobs(originalJobs, column: sortColumn, ascending: sortAscending)
            buildKanban()
            return
        }
        let filtered = originalJobs.filter { job in
            activeFilters.allSatisfy { evaluateFilter(job, filter: $0) }
        }
        jobs = sortJobs(filtered, column: sortColumn, ascending: sortAscending)
        buildKanban()
    }

    private func evaluateFilter(_ job: JobRowItem, filter: MLFilterRow) -> Bool {
        guard let col = filter.selectedColumn else { return true }
        let condition = filter.selectedCondition
        let filterValue = filter.value.lowercased()

        if col.columnType == .subItemColumn {
            if job.subItems.isEmpty { return condition == "is empty" }
            return job.subItems.contains { evaluateSubItemFilter($0, propName: col.propertyName, condition: condition, value: filterValue) }
        }

        let propValue = getShiftPropertyValue(job, propName: col.propertyName)?.lowercased() ?? ""
        return evaluateCondition(propValue, condition: condition, value: filterValue)
    }

    private func evaluateSubItemFilter(_ subItem: ShiftSubItemDto, propName: String, condition: String, value: String) -> Bool {
        let propValue: String
        switch propName {
        case "SubItem.Subitem": propValue = subItem.subitem.lowercased()
        case "SubItem.HSRequiredText": propValue = subItem.hsRequiredText.lowercased()
        case "SubItem.StatusText": propValue = subItem.statusText.lowercased()
        case "SubItem.DateStartedString": propValue = subItem.dateStartedString.lowercased()
        case "SubItem.DateCompletedString": propValue = subItem.dateCompletedString.lowercased()
        default: propValue = ""
        }
        return evaluateCondition(propValue, condition: condition, value: value)
    }

    private func evaluateCondition(_ propValue: String, condition: String, value: String) -> Bool {
        switch condition {
        case "contains": return propValue.contains(value)
        case "doesn't contain": return !propValue.contains(value)
        case "starts with": return propValue.hasPrefix(value)
        case "is": return propValue == value
        case "is not": return propValue != value
        case "is empty": return propValue.isEmpty || propValue == "not set" || propValue == "not started" || propValue == "not completed"
        case "is not empty": return !propValue.isEmpty && propValue != "not set" && propValue != "not started" && propValue != "not completed"
        default: return true
        }
    }

    private func getShiftPropertyValue(_ job: JobRowItem, propName: String) -> String? {
        switch propName {
        case "ProjectName": return job.shift.projectName
        case "ClientName": return job.shift.clientName
        case "Address": return job.shift.address
        case "DurationFromString":
            return job.shift.durationFromString.isEmpty ? job.shift.durationFrom : job.shift.durationFromString
        case "DurationToString":
            return job.shift.durationToString.isEmpty ? job.shift.durationTo : job.shift.durationToString
        case "ContractTypeText": return job.contractTypeDisplayText
        case "InvoiceStatusText": return job.invoiceDisplayText
        case "HSForms": return job.hsFormText
        case "FinalMeasure": return job.shift.finalMeasure
        case "Instructions": return job.shift.instructions
        case "StatusMessage": return job.statusDisplayText
        default: return nil
        }
    }

    private func updateFilterStatus() {
        let hasActive = !activeFilters.isEmpty
        let hasPending = !pendingFilters.isEmpty
        let filtersToApply = pendingFilters.contains { $0.isComplete }
        let showEmpty = !hasActive && !hasPending
        let totalCount = originalJobs.count
        let currentCount = jobs.count
        let statusText = !hasActive
            ? "Showing all of \(totalCount) projects"
            : "Showing \(currentCount) of \(totalCount) projects"

        hasActiveFilters = hasActive
        hasPendingFilters = hasPending
        hasFiltersToApply = filtersToApply
        showEmptyState = showEmpty
        filterStatusText = statusText
    }

    // MARK: - Helpers

    private func findJob(_ shiftId: Int) -> JobRowItem? {
        return jobs.first { $0.shift.id == shiftId }
    }

    private func findSubItem(_ subItemId: Int) -> ShiftSubItemDto? {
        for job in jobs {
            if let sub = job.subItems.first(where: { $0.id == subItemId }) {
                return sub
            }
        }
        return nil
    }

    private func parseDateTimeOrNow(_ dateStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let cleaned = dateStr.replacingOccurrences(of: "Z", with: "")
        return formatter.date(from: cleaned) ?? Date()
    }

    func formatTimestamp(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let cleaned = dateStr.replacingOccurrences(of: "Z", with: "")
        if let date = formatter.date(from: cleaned) {
            formatter.dateFormat = "dd/MM/yyyy hh:mm a"
            return formatter.string(from: date)
        }
        return dateStr
    }

    func formatAmount(_ amount: Double?) -> String {
        if let amount = amount {
            return String(format: "$%.2f", amount)
        }
        return ""
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }

    // MARK: - Status/Color maps matching MAUI exactly

    static func getStatusText(_ statusId: Int, hasQuotations: Bool = false) -> String {
        if statusId == ShiftStatus.created.rawValue && hasQuotations { return "Quoted" }
        switch ShiftStatus.fromValue(statusId) {
        case .created: return "Created"
        case .accepted: return "Accepted"
        case .ongoing: return "Started"
        case .completed: return "End"
        case .notCompleted: return "Not Completed"
        case .finishJob: return "Completed"
        }
    }

    static func getStatusColor(_ statusId: Int, hasQuotations: Bool = false) -> Color {
        if statusId == ShiftStatus.created.rawValue && hasQuotations { return Color(hex: "#007AFF") }
        switch ShiftStatus.fromValue(statusId) {
        case .created: return Color(hex: "#FF9500")
        case .accepted: return Color(hex: "#9D50DD")
        case .ongoing: return Color(hex: "#00C875")
        case .completed: return Color(hex: "#74AFCC")
        case .notCompleted: return Color(hex: "#FF3B30")
        case .finishJob: return Color(hex: "#FFCB00")
        }
    }

    static func getInvoiceText(_ invoiceStatus: Int?) -> String {
        guard let invoiceStatus = invoiceStatus else { return "" }
        switch Invoice.fromValue(invoiceStatus) {
        case .notYetCreated: return "Not Yet Created"
        case .toBeInvoiced: return "To Be Invoiced"
        case .invoiceDrafted: return "Invoice Drafted"
        case .invoiceSent: return "Invoice Sent"
        }
    }

    static func getInvoiceColor(_ invoiceStatus: Int?) -> Color {
        guard let invoiceStatus = invoiceStatus else { return Color.white }
        switch Invoice.fromValue(invoiceStatus) {
        case .notYetCreated: return Color(hex: "#C4C4C4")
        case .toBeInvoiced: return Color(hex: "#FF6D3B")
        case .invoiceDrafted: return Color(hex: "#FF0000")
        case .invoiceSent: return Color(hex: "#FFCB00")
        }
    }

    static func getContractTypeText(_ contractType: Int?) -> String {
        guard let contractType = contractType else { return "" }
        switch ContractType.fromValue(contractType) {
        case .toBeConfirmed: return "To Be Confirmed"
        case .fullContract: return "Full Contract"
        case .supplyPlaceAndFinish: return "Supply Place And Finish"
        case .placeAndFinish: return "Place And Finish"
        case .labourSupply: return "Labour Supply"
        case .boxPlaceAndFinish: return "Box Place And Finish"
        case .remedial: return "Remedial"
        case .supplyPlaceFinishAndCut: return "Supply Place Finish And Cut"
        case .placeFinishAndCut: return "Place Finish And Cut"
        case .otherServices: return "Other Services"
        case .meetings: return "Meetings"
        }
    }

    static func getContractTypeColor(_ contractType: Int?) -> Color {
        guard let contractType = contractType else { return Color.white }
        switch ContractType.fromValue(contractType) {
        case .toBeConfirmed: return Color(hex: "#C4C4C4")
        case .fullContract: return Color(hex: "#BCA58A")
        case .supplyPlaceAndFinish: return Color(hex: "#74AFCC")
        case .placeAndFinish: return Color(hex: "#CAB641")
        case .labourSupply: return Color(hex: "#175A63")
        case .boxPlaceAndFinish: return Color(hex: "#333333")
        case .remedial: return Color(hex: "#FF0000")
        case .supplyPlaceFinishAndCut: return Color(hex: "#037F4C")
        case .placeFinishAndCut: return Color(hex: "#7F5347")
        case .otherServices: return Color(hex: "#7F00FF")
        case .meetings: return Color(hex: "#FF8DA1")
        }
    }

    static func getHSFormText(_ hsForms: Int?) -> String {
        guard let hsForms = hsForms else { return "" }
        switch HSRequiredStatus.fromValue(hsForms) {
        case .noHS: return "No H&S"
        case .sssp: return "SSSP"
        case .jsa: return "JSA"
        case .take5: return "Take 5"
        case .done: return "Done"
        case .missingHS: return "Missing H&S"
        }
    }

    static func getHSFormColor(_ hsForms: Int?) -> Color {
        guard let hsForms = hsForms else { return Color.white }
        switch HSRequiredStatus.fromValue(hsForms) {
        case .noHS: return Color(hex: "#C4C4C4")
        case .sssp: return Color(hex: "#00C875")
        case .jsa: return Color(hex: "#007EB5")
        case .take5: return Color(hex: "#FF0000")
        case .done: return Color(hex: "#FFCB00")
        case .missingHS: return Color(hex: "#808080")
        }
    }

    static func getSubItemStatusText(_ status: Int) -> String {
        switch SubItemStatus.fromValue(status) {
        case .awaitingPrevious: return "Awaiting previous"
        case .workingOnIt: return "Working on it"
        case .stuck: return "Stuck"
        case .done: return "Done"
        }
    }

    static func getSubItemStatusColor(_ status: Int) -> Color {
        switch SubItemStatus.fromValue(status) {
        case .awaitingPrevious: return Color(hex: "#9D50DD")
        case .workingOnIt: return Color(hex: "#00C875")
        case .stuck: return Color(hex: "#FF0000")
        case .done: return Color(hex: "#FFCB00")
        }
    }

    static let contractTypeOptions: [StatusOption] = [
        StatusOption(name: "To Be Confirmed", value: ContractType.toBeConfirmed.rawValue, color: Color(hex: "#C4C4C4")),
        StatusOption(name: "Full Contract", value: ContractType.fullContract.rawValue, color: Color(hex: "#BCA58A")),
        StatusOption(name: "Supply Place And Finish", value: ContractType.supplyPlaceAndFinish.rawValue, color: Color(hex: "#74AFCC")),
        StatusOption(name: "Place And Finish", value: ContractType.placeAndFinish.rawValue, color: Color(hex: "#CAB641")),
        StatusOption(name: "Labour Supply", value: ContractType.labourSupply.rawValue, color: Color(hex: "#175A63")),
        StatusOption(name: "Box Place And Finish", value: ContractType.boxPlaceAndFinish.rawValue, color: Color(hex: "#333333")),
        StatusOption(name: "Remedial", value: ContractType.remedial.rawValue, color: Color(hex: "#FF0000")),
        StatusOption(name: "Supply Place Finish And Cut", value: ContractType.supplyPlaceFinishAndCut.rawValue, color: Color(hex: "#037F4C")),
        StatusOption(name: "Place Finish And Cut", value: ContractType.placeFinishAndCut.rawValue, color: Color(hex: "#7F5347")),
        StatusOption(name: "Other Services", value: ContractType.otherServices.rawValue, color: Color(hex: "#7F00FF")),
        StatusOption(name: "Meetings", value: ContractType.meetings.rawValue, color: Color(hex: "#FF8DA1"))
    ]

    static let invoiceStatusOptions: [StatusOption] = [
        StatusOption(name: "Not Yet Created", value: Invoice.notYetCreated.rawValue, color: Color(hex: "#C4C4C4")),
        StatusOption(name: "To Be Invoiced", value: Invoice.toBeInvoiced.rawValue, color: Color(hex: "#FF6D3B")),
        StatusOption(name: "Invoice Drafted", value: Invoice.invoiceDrafted.rawValue, color: Color(hex: "#FF0000")),
        StatusOption(name: "Invoice Sent", value: Invoice.invoiceSent.rawValue, color: Color(hex: "#FFCB00"))
    ]

    static let hsFormOptions: [StatusOption] = [
        StatusOption(name: "No H&S", value: HSRequiredStatus.noHS.rawValue, color: Color(hex: "#C4C4C4")),
        StatusOption(name: "SSSP", value: HSRequiredStatus.sssp.rawValue, color: Color(hex: "#00C875")),
        StatusOption(name: "JSA", value: HSRequiredStatus.jsa.rawValue, color: Color(hex: "#007EB5")),
        StatusOption(name: "Take 5", value: HSRequiredStatus.take5.rawValue, color: Color(hex: "#FF0000")),
        StatusOption(name: "Done", value: HSRequiredStatus.done.rawValue, color: Color(hex: "#FFCB00")),
        StatusOption(name: "Missing H&S", value: HSRequiredStatus.missingHS.rawValue, color: Color(hex: "#808080"))
    ]

    static let subItemStatusOptions: [StatusOption] = [
        StatusOption(name: "Awaiting previous", value: SubItemStatus.awaitingPrevious.rawValue, color: Color(hex: "#9D50DD")),
        StatusOption(name: "Working on it", value: SubItemStatus.workingOnIt.rawValue, color: Color(hex: "#00C875")),
        StatusOption(name: "Stuck", value: SubItemStatus.stuck.rawValue, color: Color(hex: "#FF0000")),
        StatusOption(name: "Done", value: SubItemStatus.done.rawValue, color: Color(hex: "#FFCB00"))
    ]
}
