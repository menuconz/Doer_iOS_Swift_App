import Foundation
import SwiftUI

// MARK: - Data Models

struct ContractTypeItem: Identifiable {
    let id: Int
    let name: String
    let color: Color
}

struct InvoiceStatusItem: Identifiable {
    let id: Int
    let name: String
    let color: Color
}

struct HSFormStatusItem: Identifiable {
    let id: Int
    let name: String
    let color: Color
}

struct SubItemStatusItem: Identifiable {
    let id: Int
    let name: String
    let color: Color
}

struct FilterColumnOption: Identifiable, Hashable {
    let id = UUID()
    let propertyName: String
    let displayName: String
    var isSubItem: Bool = false
}

struct FilterRow: Identifiable {
    let id: Int64 = Int64(Date().timeIntervalSince1970 * 1_000_000) + Int64.random(in: 0..<10000)
    var selectedColumn: FilterColumnOption? = nil
    var selectedCondition: String = ""
    var value: String = ""
    var isApplied: Bool = false

    var isComplete: Bool {
        selectedColumn != nil && !selectedCondition.isEmpty &&
        (!value.isEmpty || selectedCondition == "is empty" || selectedCondition == "is not empty")
    }

    var availableConditions: [String] {
        guard let col = selectedColumn?.propertyName else { return Self.defaultConditions }
        if col.localizedCaseInsensitiveContains("Duration") || col.localizedCaseInsensitiveContains("Date") {
            return ["contains", "doesn't contain", "is", "is not", "is empty", "is not empty"]
        }
        if col.localizedCaseInsensitiveContains("Status") || col.localizedCaseInsensitiveContains("ContractType") ||
            col.localizedCaseInsensitiveContains("InvoiceStatus") || col.localizedCaseInsensitiveContains("HSForm") {
            return ["is", "is not", "contains", "doesn't contain"]
        }
        if col.localizedCaseInsensitiveContains("HSRequired") {
            return ["is", "is not"]
        }
        return Self.defaultConditions
    }

    static let defaultConditions = ["contains", "doesn't contain", "starts with", "is", "is not", "is empty", "is not empty"]
}

struct ShiftDisplayRow: Identifiable {
    var id: String { "\(shift.id)-\(updateToken)" }
    var updateToken: UUID = UUID()
    var shift: ShiftDto
    var subItems: [ShiftSubItemDto] = []
    var statusMessage: String = ""
    var statusColor: Color = .white
    var contractTypeText: String = ""
    var contractTypeColor: Color = .white
    var invoiceStatusText: String = ""
    var invoiceStatusColor: Color = .white
    var hsFormText: String = ""
    var hsFormColor: Color = .white
    var durationFromFormatted: String = ""
    var durationToFormatted: String = ""
    var isExpanded: Bool = false
    var hasSubItems: Bool = false
    var hasQuotations: Bool = false
    var isAddSubItem: Bool = false
    var isDeleteSubItem: Bool = false
    var newSubItemName: String = ""
}

enum DayDetailDialog {
    case none
    case editor
    case dateTime
    case addressSearch
    case contractType
    case clientSelect
    case invoiceStatus
    case hsFormStatus
    case subItemHS
    case subItemStatus
    case subItemDate
    case deleteSubItem
}

@Observable
class DayDetailViewModel {
    // State
    var selectedDate: Date = Date()
    var selectedDateString: String = ""
    var projectCountText: String = ""
    var pageTitle: String = "Day Detail"
    var shiftRows: [ShiftDisplayRow] = []
    var isLoading: Bool = true
    var isManager: Bool = false
    var isAdmin: Bool = false
    var isCaregiver: Bool = false
    var isOwner: Bool = false
    var errorMessage: String? = nil

    // Sort
    var sortColumn: String = ""
    var sortAscending: Bool = true

    // Filter
    var pendingFilters: [FilterRow] = []
    var activeFilters: [FilterRow] = []
    var filterStatusText: String = ""

    // Dialog
    var activeDialog: DayDetailDialog = .none
    var editingShiftId: Int = 0
    var editingSubItemId: Int = 0
    var editorTitle: String = ""
    var editorText: String = ""
    var editorFieldName: String = ""
    var editDate: Date = Date()
    var editTime: Date = Date()
    var editIsAllDay: Bool = false

    // Address search
    var addressSearchText: String = ""
    var placeSuggestions: [PlacePrediction] = []

    // Clients
    var clients: [ClientDto] = []

    // Options
    var contractTypes: [ContractTypeItem] = []
    var invoiceStatuses: [InvoiceStatusItem] = []
    var hsFormStatuses: [HSFormStatusItem] = []
    var subItemHsOptions: [HSFormStatusItem] = []
    var subItemStatusOptions: [SubItemStatusItem] = []
    var filterColumns: [FilterColumnOption] = []

    // Delete confirm
    var deleteSubItemName: String = ""

    // Private
    private let shiftRepository: ShiftRepository
    private let clientRepository: ClientRepository
    private let preferencesManager: PreferencesManager
    private let googlePlacesService: GooglePlacesService
    private let dateStr: String
    private let shiftIdParam: Int?
    private var originalShifts: [ShiftDto] = []
    private var allShiftRows: [ShiftDisplayRow] = []
    private var addressSearchTask: Task<Void, Never>? = nil
    private var hasLoaded = false

    init(
        date: String = "",
        shiftId: Int? = nil,
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        clientRepository: ClientRepository = DIContainer.shared.clientRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService
    ) {
        self.shiftRepository = shiftRepository
        self.clientRepository = clientRepository
        self.preferencesManager = preferencesManager
        self.googlePlacesService = googlePlacesService
        self.dateStr = date.isEmpty ? Self.todayString() : date
        self.shiftIdParam = shiftId

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let parsedDate = formatter.date(from: self.dateStr) ?? Date()

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US")
        displayFormatter.dateFormat = "EEEE, MMMM dd, yyyy"
        let dateFormatted = displayFormatter.string(from: parsedDate)

        let pageTitleFormatter = DateFormatter()
        pageTitleFormatter.locale = Locale(identifier: "en_US")
        pageTitleFormatter.dateFormat = "MMM dd, yyyy"
        let pageTitleFormatted = pageTitleFormatter.string(from: parsedDate)

        selectedDate = parsedDate
        selectedDateString = dateFormatted
        pageTitle = pageTitleFormatted
        contractTypes = Self.contractTypeOptions
        invoiceStatuses = Self.invoiceStatusOptions
        hsFormStatuses = Self.hsFormStatusOptions
        subItemHsOptions = Self.hsRequiredOptions
        subItemStatusOptions = Self.subItemStatusOpts
        filterColumns = Self.buildFilterColumns()

        isAdmin = preferencesManager.isAdmin
        isManager = preferencesManager.isManager
        isCaregiver = preferencesManager.isCaregiver
        isOwner = preferencesManager.isManager || preferencesManager.isAdmin
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { @MainActor in
            await loadClients()
            await loadShifts()
        }
    }

    func refreshData() {
        Task { @MainActor in
            await loadClients()
            await loadShifts()
        }
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Data Loading

    private func loadShifts() async {
        isLoading = true

        let shifts: [ShiftDto]
        if let shiftIdParam = shiftIdParam {
            switch await shiftRepository.getShiftById(id: shiftIdParam) {
            case .success(let data): shifts = [data]
            case .error(let msg, _):
                isLoading = false
                errorMessage = msg
                return
            case .loading: return
            }
        } else {
            let result: ApiResult<[ShiftDto]>
            if isAdmin {
                result = await shiftRepository.getShiftsByDate(selectedDate: dateStr)
            } else {
                let userId = preferencesManager.userId
                result = await shiftRepository.getShiftsByUserIdAndDate(userId: userId, selectedDate: dateStr)
            }
            switch result {
            case .success(let data): shifts = data.sorted { $0.id > $1.id }
            case .error(let msg, _):
                isLoading = false
                errorMessage = msg
                return
            case .loading: return
            }
        }

        originalShifts = shifts
        let rows = await processShifts(shifts)
        allShiftRows = rows
        let countText: String
        switch rows.count {
        case 0: countText = "No jobs scheduled"
        case 1: countText = "1 job scheduled"
        default: countText = "\(rows.count) jobs scheduled"
        }

        shiftRows = rows
        projectCountText = countText
        isLoading = false
        filterStatusText = "Showing \(rows.count) of \(originalShifts.count) projects"
    }

    private func processShifts(_ shifts: [ShiftDto]) async -> [ShiftDisplayRow] {
        var rows: [ShiftDisplayRow] = []
        for rawShift in shifts {
            var shift = rawShift
            if (shift.clientName ?? "").isEmpty, let clientId = shift.clientId, clientId > 0 {
                let clientName = clients.first { $0.id == clientId }?.name
                if let name = clientName, !name.isEmpty {
                    shift.clientName = name
                }
            }

            var subItems: [ShiftSubItemDto] = []
            if case .success(let items) = await shiftRepository.getSubItemsByJobId(id: shift.id) {
                subItems = items.map { item in
                    var enriched = item
                    if enriched.dateStartedString.isEmpty, let ds = enriched.dateStarted, !ds.isEmpty {
                        enriched.dateStartedString = Self.formatSubItemDate(ds)
                    }
                    if enriched.dateCompletedString.isEmpty, let dc = enriched.dateCompleted, !dc.isEmpty {
                        enriched.dateCompletedString = Self.formatSubItemDate(dc)
                    }
                    return enriched
                }
            }

            var quotationsExist = false
            if case .success(let quotations) = await shiftRepository.getQuotationsByJobId(id: shift.id) {
                quotationsExist = !quotations.isEmpty
            }
            let hasQuotations = quotationsExist && shift.statusId == 1 && isOwner

            rows.append(ShiftDisplayRow(
                shift: shift,
                subItems: subItems,
                statusMessage: Self.getStatusMessage(statusId: shift.statusId, hasQuotations: hasQuotations),
                statusColor: CalendarViewModel.getStatusColor(shift.statusId, hasQuotations: hasQuotations),
                contractTypeText: Self.getContractTypeText(shift.contractType),
                contractTypeColor: CalendarViewModel.getContractTypeColor(shift.contractType),
                invoiceStatusText: Self.getInvoiceStatusText(shift.invoiceStatus),
                invoiceStatusColor: Self.getInvoiceStatusColor(shift.invoiceStatus),
                hsFormText: Self.getHSFormText(shift.hsForms),
                hsFormColor: Self.getHSFormColor(shift.hsForms),
                durationFromFormatted: Self.formatDateTime(shift.durationFrom),
                durationToFormatted: Self.formatDateTime(shift.durationTo),
                hasSubItems: !subItems.isEmpty,
                hasQuotations: hasQuotations,
                isAddSubItem: isOwner,
                isDeleteSubItem: isOwner
            ))
        }
        return rows
    }

    private func loadClients() async {
        if case .success(let data) = await clientRepository.getAllClients() {
            let selectClient = ClientDto(id: 0, name: "Select Client")
            clients = [selectClient] + data
        }
    }

    // MARK: - Expand / Collapse

    func toggleExpand(_ shiftId: Int) {
        func toggle(_ row: ShiftDisplayRow) -> ShiftDisplayRow {
            guard row.shift.id == shiftId else { return row }
            var r = row; r.isExpanded = !r.isExpanded; return r
        }
        allShiftRows = allShiftRows.map { toggle($0) }
        shiftRows = shiftRows.map { toggle($0) }
    }

    // MARK: - Sorting

    func sortBy(_ column: String) {
        let ascending = sortColumn == column ? !sortAscending : true

        let comp: (ShiftDisplayRow, ShiftDisplayRow) -> Bool = { a, b in
            let valA = self.getSortValue(a, column)
            let valB = self.getSortValue(b, column)
            return ascending ? valA < valB : valA > valB
        }

        allShiftRows = allShiftRows.sorted(by: comp)
        shiftRows = shiftRows.sorted(by: comp)
        sortColumn = column
        sortAscending = ascending
    }

    private func getSortValue(_ row: ShiftDisplayRow, _ column: String) -> String {
        switch column {
        case "ProjectName": return row.shift.projectName
        case "ClientName": return row.shift.clientName ?? ""
        case "Address": return row.shift.address
        case "DurationFromString": return row.shift.durationFrom
        case "DurationToString": return row.shift.durationTo
        case "ContractType": return row.contractTypeText
        case "InvoiceStatus": return row.invoiceStatusText
        case "HSForm": return row.hsFormText
        case "FinalMeasure": return row.shift.finalMeasure
        case "Instructions": return row.shift.instructions
        case "Amount": return String(format: "%015.2f", row.shift.amount ?? 0.0)
        case "AcceptedQuoteAmount": return String(format: "%015.2f", row.shift.acceptedQuoteAmount ?? 0.0)
        case "StatusMessage": return row.statusMessage
        default: return ""
        }
    }

    func getSortIcon(_ column: String) -> String {
        guard sortColumn == column else { return "" }
        return sortAscending ? "\u{25B2}" : "\u{25BC}"
    }

    // MARK: - Filters

    func addFilter() {
        pendingFilters.append(FilterRow())
    }

    func updatePendingFilterColumn(_ filterId: Int64, _ column: FilterColumnOption) {
        pendingFilters = pendingFilters.map {
            guard $0.id == filterId else { return $0 }
            var f = $0; f.selectedColumn = column; f.selectedCondition = ""; f.value = ""; return f
        }
    }

    func updatePendingFilterCondition(_ filterId: Int64, _ condition: String) {
        pendingFilters = pendingFilters.map {
            guard $0.id == filterId else { return $0 }
            var f = $0; f.selectedCondition = condition; return f
        }
    }

    func updatePendingFilterValue(_ filterId: Int64, _ value: String) {
        pendingFilters = pendingFilters.map {
            guard $0.id == filterId else { return $0 }
            var f = $0; f.value = value; return f
        }
    }

    func removeFilter(_ filterId: Int64) {
        pendingFilters = pendingFilters.filter { $0.id != filterId }
        activeFilters = activeFilters.filter { $0.id != filterId }
        applyFiltersToData()
    }

    func applyFilters() {
        let complete = pendingFilters.filter { $0.isComplete }
        guard !complete.isEmpty else { return }
        activeFilters = activeFilters + complete.map { var f = $0; f.isApplied = true; return f }
        pendingFilters = pendingFilters.filter { !$0.isComplete }
        applyFiltersToData()
    }

    func clearAllFilters() {
        pendingFilters = []
        activeFilters = []
        applyFiltersToData()
    }

    private func applyFiltersToData() {
        if activeFilters.isEmpty {
            shiftRows = allShiftRows
            filterStatusText = "Showing \(allShiftRows.count) of \(allShiftRows.count) projects"
            return
        }
        let filtered = allShiftRows.filter { row in
            activeFilters.allSatisfy { filter in matchesFilterRow(row, filter) }
        }
        shiftRows = filtered
        filterStatusText = "Showing \(filtered.count) of \(allShiftRows.count) projects"
    }

    private func matchesFilterRow(_ row: ShiftDisplayRow, _ filter: FilterRow) -> Bool {
        guard let column = filter.selectedColumn else { return true }
        let condition = filter.selectedCondition
        let filterValue = filter.value.lowercased()

        if column.isSubItem {
            if row.subItems.isEmpty { return condition == "is empty" }
            return row.subItems.contains { subItem in
                let propValue = Self.getSubItemPropertyValue(subItem, column.propertyName).lowercased()
                return Self.evaluateCondition(propValue, condition, filterValue)
            }
        }

        let propValue: String
        if column.propertyName == "StatusMessage" {
            propValue = row.statusMessage.lowercased()
        } else {
            propValue = Self.getShiftPropertyValue(row.shift, column.propertyName).lowercased()
        }
        return Self.evaluateCondition(propValue, condition, filterValue)
    }

    private static func evaluateCondition(_ propValue: String, _ condition: String, _ filterValue: String) -> Bool {
        switch condition {
        case "contains": return propValue.contains(filterValue)
        case "doesn't contain": return !propValue.contains(filterValue)
        case "starts with": return propValue.hasPrefix(filterValue)
        case "is": return propValue == filterValue
        case "is not": return propValue != filterValue
        case "is empty": return propValue.isEmpty || propValue == "not set" || propValue == "not started" || propValue == "not completed"
        case "is not empty": return !propValue.isEmpty && propValue != "not set" && propValue != "not started" && propValue != "not completed"
        default: return true
        }
    }

    private static func getSubItemPropertyValue(_ subItem: ShiftSubItemDto, _ propertyName: String) -> String {
        switch propertyName {
        case "SubItem": return subItem.subitem
        case "SubItemHSRequired": return getSubItemHSText(subItem.hsRequired)
        case "SubItemStatus": return getSubItemStatusText(subItem.status)
        case "SubItemDateStarted": return subItem.dateStartedString
        case "SubItemCompleted": return subItem.dateCompletedString
        default: return ""
        }
    }

    private static func getShiftPropertyValue(_ shift: ShiftDto, _ propertyName: String) -> String {
        switch propertyName {
        case "ProjectName": return shift.projectName
        case "ClientName": return shift.clientName ?? ""
        case "Address": return shift.address
        case "DurationFrom": return formatDateTime(shift.durationFrom)
        case "DurationTo": return formatDateTime(shift.durationTo)
        case "ContractType": return getContractTypeText(shift.contractType)
        case "InvoiceStatus": return getInvoiceStatusText(shift.invoiceStatus)
        case "HSForm": return getHSFormText(shift.hsForms)
        case "FinalMeasure": return shift.finalMeasure
        case "Instructions": return shift.instructions
        case "StatusMessage": return getStatusMessage(statusId: shift.statusId, hasQuotations: shift.hasQuotations)
        default: return ""
        }
    }

    // MARK: - Inline Editing - Open Dialogs

    func editProjectName(_ shiftId: Int) {
        guard !isCaregiver, let shift = findShift(shiftId) else { return }
        activeDialog = .editor
        editingShiftId = shiftId
        editorTitle = "Edit Project Name"
        editorText = shift.projectName
        editorFieldName = "ProjectName"
    }

    func editFinalMeasure(_ shiftId: Int) {
        guard !isCaregiver, let shift = findShift(shiftId) else { return }
        activeDialog = .editor
        editingShiftId = shiftId
        editorTitle = "Edit Final Measure"
        editorText = shift.finalMeasure
        editorFieldName = "FinalMeasure"
    }

    func editJobDescription(_ shiftId: Int) {
        guard !isCaregiver, let shift = findShift(shiftId) else { return }
        activeDialog = .editor
        editingShiftId = shiftId
        editorTitle = "Edit Job Description"
        editorText = shift.instructions
        editorFieldName = "Instructions"
    }

    func editDurationFrom(_ shiftId: Int) {
        guard !isCaregiver, let shift = findShift(shiftId) else { return }
        let (date, time) = parseDateTimeParts(shift.durationFrom)
        activeDialog = .dateTime
        editingShiftId = shiftId
        editorFieldName = "DurationFrom"
        editDate = date
        editTime = time
        editIsAllDay = shift.isAllDay
    }

    func editDurationTo(_ shiftId: Int) {
        guard !isCaregiver, let shift = findShift(shiftId) else { return }
        let (date, time) = parseDateTimeParts(shift.durationTo)
        activeDialog = .dateTime
        editingShiftId = shiftId
        editorFieldName = "DurationTo"
        editDate = date
        editTime = time
        editIsAllDay = shift.isAllDay
    }

    func editAddress(_ shiftId: Int) {
        guard !isCaregiver, let shift = findShift(shiftId) else { return }
        activeDialog = .addressSearch
        editingShiftId = shiftId
        addressSearchText = shift.address
        placeSuggestions = []
    }

    func openContractType(_ shiftId: Int) {
        guard !isCaregiver else { return }
        activeDialog = .contractType
        editingShiftId = shiftId
    }

    func openClientSelect(_ shiftId: Int) {
        guard !isCaregiver else { return }
        activeDialog = .clientSelect
        editingShiftId = shiftId
    }

    func openInvoiceStatus(_ shiftId: Int) {
        guard !isCaregiver else { return }
        activeDialog = .invoiceStatus
        editingShiftId = shiftId
    }

    func openHSFormStatus(_ shiftId: Int) {
        guard !isCaregiver else { return }
        activeDialog = .hsFormStatus
        editingShiftId = shiftId
    }

    func openSubItemHS(_ shiftId: Int, _ subItemId: Int) {
        guard !isCaregiver else { return }
        activeDialog = .subItemHS
        editingShiftId = shiftId
        editingSubItemId = subItemId
    }

    func openSubItemStatus(_ shiftId: Int, _ subItemId: Int) {
        guard !isCaregiver else { return }
        activeDialog = .subItemStatus
        editingShiftId = shiftId
        editingSubItemId = subItemId
    }

    func openSubItemDateStarted(_ shiftId: Int, _ subItemId: Int) {
        guard !isCaregiver, let subItem = findSubItem(shiftId, subItemId) else { return }
        let (date, time): (Date, Date)
        if let ds = subItem.dateStarted, !ds.isEmpty {
            (date, time) = parseDateTimeParts(ds)
        } else {
            date = Date()
            time = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
        }
        activeDialog = .subItemDate
        editingShiftId = shiftId
        editingSubItemId = subItemId
        editDate = date
        editTime = time
    }

    func confirmDeleteSubItem(_ shiftId: Int, _ subItemId: Int) {
        let subItem = findSubItem(shiftId, subItemId)
        activeDialog = .deleteSubItem
        editingShiftId = shiftId
        editingSubItemId = subItemId
        deleteSubItemName = subItem?.subitem ?? "this sub-item"
    }

    func dismissDialog() {
        activeDialog = .none
        placeSuggestions = []
    }

    // MARK: - Inline Editing - Save Actions

    func saveEditorText(_ text: String) {
        guard var shift = findShift(editingShiftId) else { return }
        switch editorFieldName {
        case "ProjectName": shift.projectName = text
        case "FinalMeasure": shift.finalMeasure = text
        case "Instructions": shift.instructions = text
        default: break
        }
        dismissDialog()
        updateShift(shift)
    }

    func saveDateTime(_ date: Date, _ time: Date) {
        guard var shift = findShift(editingShiftId) else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let dateTimeStr = "\(dateFormatter.string(from: date))T\(timeFormatter.string(from: time))"
        switch editorFieldName {
        case "DurationFrom": shift.durationFrom = dateTimeStr
        case "DurationTo": shift.durationTo = dateTimeStr
        default: break
        }
        dismissDialog()
        updateShift(shift)
    }

    func saveAddress(_ address: String, _ latitude: Double, _ longitude: Double) {
        guard var shift = findShift(editingShiftId) else { return }
        shift.address = address
        shift.latitude = latitude
        shift.longitude = longitude
        dismissDialog()
        updateShift(shift)
    }

    func selectContractType(_ item: ContractTypeItem) {
        guard var shift = findShift(editingShiftId) else { return }
        shift.contractType = item.id
        dismissDialog()
        updateShift(shift)
    }

    func selectClient(_ client: ClientDto) {
        guard var shift = findShift(editingShiftId) else { return }
        shift.clientId = client.id > 0 ? client.id : nil
        shift.clientName = client.id > 0 ? client.name : ""
        dismissDialog()
        updateShift(shift)
    }

    func selectInvoiceStatus(_ item: InvoiceStatusItem) {
        guard var shift = findShift(editingShiftId) else { return }
        shift.invoiceStatus = item.id
        dismissDialog()
        updateShift(shift)
    }

    func selectHSFormStatus(_ item: HSFormStatusItem) {
        guard var shift = findShift(editingShiftId) else { return }
        shift.hsForms = item.id
        dismissDialog()
        updateShift(shift)
    }

    func selectSubItemHS(_ item: HSFormStatusItem) {
        guard var subItem = findSubItem(editingShiftId, editingSubItemId) else { return }
        subItem.hsRequired = item.id
        dismissDialog()
        updateSubItem(editingShiftId, subItem)
    }

    func selectSubItemStatus(_ item: SubItemStatusItem) {
        guard var subItem = findSubItem(editingShiftId, editingSubItemId) else { return }
        subItem.status = item.id
        dismissDialog()
        updateSubItem(editingShiftId, subItem)
    }

    func saveSubItemDate(_ date: Date, _ time: Date) {
        guard var subItem = findSubItem(editingShiftId, editingSubItemId) else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let dateTimeStr = "\(dateFormatter.string(from: date))T\(timeFormatter.string(from: time))"
        subItem.dateStarted = dateTimeStr

        // Also update the display string
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        displayFormatter.locale = Locale(identifier: "en_US")
        if let parsed = displayFormatter.date(from: dateTimeStr) {
            displayFormatter.dateFormat = "dd MMM yyyy, h:mm a"
            subItem.dateStartedString = displayFormatter.string(from: parsed)
        } else {
            subItem.dateStartedString = dateTimeStr
        }

        dismissDialog()
        updateSubItem(editingShiftId, subItem)
    }

    // MARK: - Address Search

    func onAddressSearchChange(_ text: String) {
        addressSearchText = text
        addressSearchTask?.cancel()
        if text.count >= 3 {
            addressSearchTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
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
                saveAddress(place.address, place.latitude, place.longitude)
            }
        }
    }

    // MARK: - Sub-Item CRUD

    func updateNewSubItemName(_ shiftId: Int, _ name: String) {
        shiftRows = shiftRows.map {
            guard $0.shift.id == shiftId else { return $0 }
            var r = $0; r.newSubItemName = name; return r
        }
    }

    func addSubItem(_ shiftId: Int) {
        guard let row = shiftRows.first(where: { $0.shift.id == shiftId }) else { return }
        let name = row.newSubItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        Task { @MainActor in
            let userId = preferencesManager.userId
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let now = formatter.string(from: Date())

            var newSubItem = ShiftSubItemDto()
            newSubItem.shiftId = shiftId
            newSubItem.subitem = name
            newSubItem.createdBy = userId
            newSubItem.createdDate = now
            newSubItem.modifiedBy = userId
            newSubItem.modifiedDate = now

            switch await shiftRepository.addSubItems(subItem: newSubItem) {
            case .success(let addedSubItem):
                func addToRow(_ row: ShiftDisplayRow) -> ShiftDisplayRow {
                    guard row.shift.id == shiftId else { return row }
                    var r = row
                    r.subItems = r.subItems + [addedSubItem]
                    r.hasSubItems = true
                    r.newSubItemName = ""
                    return r
                }
                allShiftRows = allShiftRows.map { addToRow($0) }
                shiftRows = shiftRows.map { addToRow($0) }
                await checkAndUpdateMainHSStatus(shiftId)
            case .error(let msg, _):
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func deleteSubItem() {
        let subItemId = editingSubItemId
        dismissDialog()

        Task { @MainActor in
            switch await shiftRepository.deleteSubItem(id: subItemId) {
            case .success:
                func removeFromRow(_ row: ShiftDisplayRow) -> ShiftDisplayRow {
                    let updated = row.subItems.filter { $0.id != subItemId }
                    guard updated.count != row.subItems.count else { return row }
                    var r = row
                    r.subItems = updated
                    r.hasSubItems = !updated.isEmpty
                    return r
                }
                allShiftRows = allShiftRows.map { removeFromRow($0) }
                shiftRows = shiftRows.map { removeFromRow($0) }
            case .error(let msg, _):
                errorMessage = msg
            case .loading: break
            }
        }
    }

    // MARK: - API Update Calls

    private func updateShift(_ shift: ShiftDto) {
        Task { @MainActor in
            let userId = preferencesManager.userId
            var shiftToUpdate = shift
            shiftToUpdate.modifiedBy = userId
            switch await shiftRepository.updateShift(shiftDetail: shiftToUpdate) {
            case .success(let data):
                print("[DEBUG] Update shift success, id: \(data.id), projectName: \(data.projectName)")
                updateShiftInPlace(data)
            case .error(let msg, _):
                print("[DEBUG] Update shift error: \(msg)")
                errorMessage = msg
            case .loading: break
            }
        }
    }

    private func updateShiftInPlace(_ updatedShift: ShiftDto) {
        var enrichedShift = updatedShift
        if (enrichedShift.clientName ?? "").isEmpty, let clientId = enrichedShift.clientId, clientId > 0 {
            if let clientName = clients.first(where: { $0.id == clientId })?.name, !clientName.isEmpty {
                enrichedShift.clientName = clientName
            }
        }

        func updateRow(_ row: ShiftDisplayRow) -> ShiftDisplayRow {
            guard row.shift.id == enrichedShift.id else { return row }
            var r = row
            r.shift = enrichedShift
            r.updateToken = UUID()
            r.statusMessage = Self.getStatusMessage(statusId: enrichedShift.statusId, hasQuotations: row.hasQuotations)
            r.statusColor = CalendarViewModel.getStatusColor(enrichedShift.statusId, hasQuotations: row.hasQuotations)
            r.contractTypeText = Self.getContractTypeText(enrichedShift.contractType)
            r.contractTypeColor = CalendarViewModel.getContractTypeColor(enrichedShift.contractType)
            r.invoiceStatusText = Self.getInvoiceStatusText(enrichedShift.invoiceStatus)
            r.invoiceStatusColor = Self.getInvoiceStatusColor(enrichedShift.invoiceStatus)
            r.hsFormText = Self.getHSFormText(enrichedShift.hsForms)
            r.hsFormColor = Self.getHSFormColor(enrichedShift.hsForms)
            r.durationFromFormatted = Self.formatDateTime(enrichedShift.durationFrom)
            r.durationToFormatted = Self.formatDateTime(enrichedShift.durationTo)
            return r
        }

        originalShifts = originalShifts.map { $0.id == enrichedShift.id ? enrichedShift : $0 }
        allShiftRows = allShiftRows.map { updateRow($0) }
        shiftRows = shiftRows.map { updateRow($0) }
    }

    private func updateSubItem(_ shiftId: Int, _ subItem: ShiftSubItemDto) {
        Task { @MainActor in
            let userId = preferencesManager.userId
            var subItemToUpdate = subItem
            subItemToUpdate.modifiedBy = userId
            switch await shiftRepository.editSubItems(subItem: subItemToUpdate) {
            case .success(let returnedSubItem):
                updateSubItemInPlace(shiftId, returnedSubItem)
                await checkAndUpdateMainHSStatus(shiftId)
            case .error(let msg, _):
                errorMessage = msg
            case .loading: break
            }
        }
    }

    private func updateSubItemInPlace(_ shiftId: Int, _ updatedSubItem: ShiftSubItemDto) {
        var enriched = updatedSubItem

        // Ensure display strings are populated from raw dates if server didn't return them
        if enriched.dateStartedString.isEmpty, let ds = enriched.dateStarted, !ds.isEmpty {
            enriched.dateStartedString = Self.formatSubItemDate(ds)
        }
        if enriched.dateCompletedString.isEmpty, let dc = enriched.dateCompleted, !dc.isEmpty {
            enriched.dateCompletedString = Self.formatSubItemDate(dc)
        }

        func updateRow(_ row: ShiftDisplayRow) -> ShiftDisplayRow {
            guard row.shift.id == shiftId else { return row }
            var r = row
            r.subItems = r.subItems.map { $0.id == enriched.id ? enriched : $0 }
            r.updateToken = UUID()
            return r
        }
        allShiftRows = allShiftRows.map { updateRow($0) }
        shiftRows = shiftRows.map { updateRow($0) }
    }

    private static func formatSubItemDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let cleaned = String(dateStr.prefix(19))
        guard let date = formatter.date(from: cleaned) else { return dateStr }
        formatter.dateFormat = "dd/MM/yyyy hh:mm a"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }

    private func checkAndUpdateMainHSStatus(_ shiftId: Int) async {
        guard let row = allShiftRows.first(where: { $0.shift.id == shiftId }) else { return }
        guard !row.subItems.isEmpty else { return }
        let allDoneOrNoHS = row.subItems.allSatisfy { $0.hsRequired == 4 || $0.hsRequired == 0 }
        if allDoneOrNoHS && row.shift.hsForms != 4 {
            let userId = preferencesManager.userId
            var updatedShift = row.shift
            updatedShift.hsForms = 4
            updatedShift.modifiedBy = userId
            _ = await shiftRepository.updateShift(shiftDetail: updatedShift)
            updateShiftInPlace(updatedShift)
        }
    }

    // MARK: - Editor State Updates

    func updateEditorText(_ text: String) { editorText = text }
    func updateEditDate(_ date: Date) { editDate = date }
    func updateEditTime(_ time: Date) { editTime = time }

    // MARK: - Helpers

    func clearError() { errorMessage = nil }

    func refresh() {
        Task { @MainActor in await loadShifts() }
    }

    private func findShift(_ shiftId: Int) -> ShiftDto? {
        shiftRows.first { $0.shift.id == shiftId }?.shift
    }

    private func findSubItem(_ shiftId: Int, _ subItemId: Int) -> ShiftSubItemDto? {
        shiftRows.first { $0.shift.id == shiftId }?.subItems.first { $0.id == subItemId }
    }

    private func parseDateTimeParts(_ dateStr: String) -> (Date, Date) {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let datePart = formatter.date(from: String(dateStr.prefix(10))) ?? Date()

        var timePart = cal.date(from: DateComponents(hour: 12, minute: 0))!
        if dateStr.count >= 19 {
            let timeStr = String(dateStr[dateStr.index(dateStr.startIndex, offsetBy: 11)..<dateStr.index(dateStr.startIndex, offsetBy: 19)])
            formatter.dateFormat = "HH:mm:ss"
            if let t = formatter.date(from: timeStr) {
                timePart = t
            }
        }
        return (datePart, timePart)
    }

    // MARK: - Static Helpers

    static func getStatusMessage(statusId: Int, hasQuotations: Bool) -> String {
        switch statusId {
        case 1: return hasQuotations ? "Quoted" : "Created"
        case 2: return "Accepted"
        case 3: return "Started"
        case 4: return "End"
        case 5: return "Not Completed"
        case 6: return "Completed"
        default: return ""
        }
    }

    static func getContractTypeText(_ contractType: Int?) -> String {
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
        default: return ""
        }
    }

    static func getInvoiceStatusText(_ invoiceStatus: Int?) -> String {
        switch invoiceStatus {
        case 1: return "Not Yet Created"
        case 2: return "To Be Invoiced"
        case 3: return "Invoice Drafted"
        case 4: return "Invoice Sent"
        default: return ""
        }
    }

    static func getHSFormText(_ hsForms: Int?) -> String {
        switch hsForms {
        case 0: return "No H&S"
        case 1: return "SSSP"
        case 2: return "JSA"
        case 3: return "Take 5"
        case 4: return "Done"
        case 5: return "Missing H&S"
        default: return ""
        }
    }

    static func getHSFormColor(_ hsForms: Int?) -> Color {
        switch hsForms {
        case 0: return Color(hex: "C4C4C4")
        case 1: return Color(hex: "00C875")
        case 2: return Color(hex: "007EB5")
        case 3: return Color(hex: "FF0000")
        case 4: return Color(hex: "FFCB00")
        case 5: return Color(hex: "808080")
        default: return .white
        }
    }

    static func getInvoiceStatusColor(_ invoiceStatus: Int?) -> Color {
        switch invoiceStatus {
        case 1: return Color(hex: "C4C4C4")
        case 2: return Color(hex: "FF6D3B")
        case 3: return Color(hex: "FF0000")
        case 4: return Color(hex: "FFCB00")
        default: return .white
        }
    }

    static func getSubItemHSColor(_ hsRequired: Int) -> Color {
        switch hsRequired {
        case 0: return Color(hex: "C4C4C4")
        case 1: return Color(hex: "00C875")
        case 2: return Color(hex: "007EB5")
        case 3: return Color(hex: "FF0000")
        case 4: return Color(hex: "FFCB00")
        case 5: return Color(hex: "808080")
        default: return .white
        }
    }

    static func getSubItemHSText(_ hsRequired: Int) -> String {
        switch hsRequired {
        case 0: return "No H&S"
        case 1: return "SSSP"
        case 2: return "JSA"
        case 3: return "Take 5"
        case 4: return "Done"
        case 5: return "Missing H&S"
        default: return ""
        }
    }

    static func getSubItemStatusColor(_ status: Int) -> Color {
        switch status {
        case 1: return Color(hex: "9D50DD")
        case 2: return Color(hex: "00C875")
        case 3: return Color(hex: "FF0000")
        case 4: return Color(hex: "FFCB00")
        default: return .white
        }
    }

    static func getSubItemStatusText(_ status: Int) -> String {
        switch status {
        case 1: return "Awaiting previous"
        case 2: return "Working on it"
        case 3: return "Stuck"
        case 4: return "Done"
        default: return ""
        }
    }

    static func formatDateTime(_ dateStr: String) -> String {
        guard dateStr.count >= 16 else { return dateStr }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(dateStr.prefix(10))) else { return dateStr }

        let endIdx = min(19, dateStr.count)
        let timeStr = String(dateStr[dateStr.index(dateStr.startIndex, offsetBy: 11)..<dateStr.index(dateStr.startIndex, offsetBy: endIdx)])
        formatter.dateFormat = "HH:mm:ss"
        guard let time = formatter.date(from: timeStr) else { return dateStr }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "dd/MM/yyyy"
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "en_US")
        timeFmt.dateFormat = "h:mm a"
        return "\(dateFmt.string(from: date)) \(timeFmt.string(from: time))"
    }

    // MARK: - Option Lists

    static let contractTypeOptions: [ContractTypeItem] = [
        ContractTypeItem(id: 1, name: "To Be Confirmed", color: Color(hex: "C4C4C4")),
        ContractTypeItem(id: 2, name: "Full Contract", color: Color(hex: "BCA58A")),
        ContractTypeItem(id: 3, name: "Supply Place And Finish", color: Color(hex: "74AFCC")),
        ContractTypeItem(id: 4, name: "Place And Finish", color: Color(hex: "CAB641")),
        ContractTypeItem(id: 5, name: "Labour Supply", color: Color(hex: "175A63")),
        ContractTypeItem(id: 6, name: "Box Place And Finish", color: Color(hex: "333333")),
        ContractTypeItem(id: 7, name: "Remedial", color: Color(hex: "FF0000")),
        ContractTypeItem(id: 8, name: "Supply Place Finish And Cut", color: Color(hex: "037F4C")),
        ContractTypeItem(id: 9, name: "Place Finish And Cut", color: Color(hex: "7F5347")),
        ContractTypeItem(id: 10, name: "Other Services", color: Color(hex: "7F00FF")),
        ContractTypeItem(id: 11, name: "Meetings", color: Color(hex: "FF8DA1"))
    ]

    static let invoiceStatusOptions: [InvoiceStatusItem] = [
        InvoiceStatusItem(id: 1, name: "Not Yet Created", color: Color(hex: "C4C4C4")),
        InvoiceStatusItem(id: 2, name: "To Be Invoiced", color: Color(hex: "FF6D3B")),
        InvoiceStatusItem(id: 3, name: "Invoice Drafted", color: Color(hex: "FF0000")),
        InvoiceStatusItem(id: 4, name: "Invoice Sent", color: Color(hex: "FFCB00"))
    ]

    static let hsFormStatusOptions: [HSFormStatusItem] = [
        HSFormStatusItem(id: 0, name: "No H&S", color: Color(hex: "C4C4C4")),
        HSFormStatusItem(id: 1, name: "SSSP", color: Color(hex: "00C875")),
        HSFormStatusItem(id: 2, name: "JSA", color: Color(hex: "007EB5")),
        HSFormStatusItem(id: 3, name: "Take 5", color: Color(hex: "FF0000")),
        HSFormStatusItem(id: 4, name: "Done", color: Color(hex: "FFCB00")),
        HSFormStatusItem(id: 5, name: "Missing H&S", color: Color(hex: "808080"))
    ]

    static let hsRequiredOptions: [HSFormStatusItem] = hsFormStatusOptions

    static let subItemStatusOpts: [SubItemStatusItem] = [
        SubItemStatusItem(id: 1, name: "Awaiting previous", color: Color(hex: "9D50DD")),
        SubItemStatusItem(id: 2, name: "Working on it", color: Color(hex: "00C875")),
        SubItemStatusItem(id: 3, name: "Stuck", color: Color(hex: "FF0000")),
        SubItemStatusItem(id: 4, name: "Done", color: Color(hex: "FFCB00"))
    ]

    static func buildFilterColumns() -> [FilterColumnOption] {
        return [
            FilterColumnOption(propertyName: "ProjectName", displayName: "Project Name"),
            FilterColumnOption(propertyName: "ClientName", displayName: "Client Name"),
            FilterColumnOption(propertyName: "Address", displayName: "Address"),
            FilterColumnOption(propertyName: "DurationFrom", displayName: "Duration From"),
            FilterColumnOption(propertyName: "DurationTo", displayName: "Duration To"),
            FilterColumnOption(propertyName: "ContractType", displayName: "Contract Type"),
            FilterColumnOption(propertyName: "InvoiceStatus", displayName: "Invoice Status"),
            FilterColumnOption(propertyName: "HSForm", displayName: "H&S Status"),
            FilterColumnOption(propertyName: "FinalMeasure", displayName: "Final Measure"),
            FilterColumnOption(propertyName: "Instructions", displayName: "Job Description"),
            FilterColumnOption(propertyName: "StatusMessage", displayName: "Status"),
            FilterColumnOption(propertyName: "SubItem", displayName: "Sub Item", isSubItem: true),
            FilterColumnOption(propertyName: "SubItemHSRequired", displayName: "Sub H&S", isSubItem: true),
            FilterColumnOption(propertyName: "SubItemStatus", displayName: "Sub Status", isSubItem: true),
            FilterColumnOption(propertyName: "SubItemDateStarted", displayName: "Sub Date Started", isSubItem: true),
            FilterColumnOption(propertyName: "SubItemCompleted", displayName: "Sub Completed", isSubItem: true)
        ]
    }
}
