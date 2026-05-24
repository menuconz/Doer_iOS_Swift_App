import Foundation
import SwiftUI
import UIKit

enum EditField {
    case projectDescription, owner, status, cost, client, location, contractType
}

@Observable
class NewLeadsViewModel {
    var isLoading: Bool = true
    var leads: [LeadsDto] = []
    var clients: [ClientDto] = []
    var owners: [UserDto] = []
    var sortColumn: String = ""
    var sortAscending: Bool = true
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var isUpdating: Bool = false
    // Edit dialog state
    var editingLead: LeadsDto? = nil
    var editField: EditField? = nil
    var editValue: String = ""
    // Location search
    var searchAddress: String = ""
    var placeList: [PlacePrediction] = []
    var showPlaceList: Bool = false

    private let leadRepository: LeadRepository
    private let clientRepository: ClientRepository
    private let accountRepository: AccountRepository
    private let preferencesManager: PreferencesManager
    private let googlePlacesService: GooglePlacesService
    private let boardConfigCache: BoardConfigCache
    private var hasLoaded = false

    init(
        leadRepository: LeadRepository = DIContainer.shared.leadRepository,
        clientRepository: ClientRepository = DIContainer.shared.clientRepository,
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService,
        boardConfigCache: BoardConfigCache = DIContainer.shared.boardConfigCache
    ) {
        self.leadRepository = leadRepository
        self.clientRepository = clientRepository
        self.accountRepository = accountRepository
        self.preferencesManager = preferencesManager
        self.googlePlacesService = googlePlacesService
        self.boardConfigCache = boardConfigCache
    }

    // Cache-aware accessors so admin-renamed labels and colours appear automatically.
    func leadStatusColor(_ statusId: Int) -> Color {
        let argb = boardConfigCache.color(
            "LeadStatus", value: statusId,
            fallback: argbFromColor(Self.getLeadStatusColor(statusId))
        )
        return Color(argb: argb)
    }

    func contractTypeColorDynamic(_ contractType: Int?) -> Color {
        let argb = boardConfigCache.color(
            "ContractType", value: contractType ?? -1,
            fallback: argbFromColor(Self.getContractTypeColor(contractType))
        )
        return Color(argb: argb)
    }

    // Cache-aware list of LeadStatus picker options.
    var dynamicLeadStatuses: [(Int, String)] {
        let cached = boardConfigCache.getOptions("LeadStatus")
        return cached.isEmpty ? Self.leadStatuses : cached.map { ($0.value, $0.displayName) }
    }

    // Cache-aware list of ContractType picker options.
    var dynamicContractTypes: [(Int, String)] {
        let cached = boardConfigCache.getOptions("ContractType")
        return cached.isEmpty ? Self.contractTypes : cached.map { ($0.value, $0.displayName) }
    }

    // Resolve a status id to a display name via cache; fall back to the value baked
    // into the row when the cache hasn't loaded or the id is unknown.
    func leadStatusName(_ statusId: Int, fallback: String) -> String {
        boardConfigCache.displayName("LeadStatus", value: statusId, fallback: fallback)
    }

    func contractTypeName(_ contractType: Int?, fallback: String) -> String {
        boardConfigCache.displayName("ContractType", value: contractType ?? -1, fallback: fallback)
    }

    private func argbFromColor(_ c: Color) -> UInt32 {
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let R = UInt32((r * 255).rounded()) & 0xFF
        let G = UInt32((g * 255).rounded()) & 0xFF
        let B = UInt32((b * 255).rounded()) & 0xFF
        let A = UInt32((a * 255).rounded()) & 0xFF
        return (A << 24) | (R << 16) | (G << 8) | B
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadData()
    }

    func refresh() {
        loadData()
    }

    private func loadData() {
        Task { @MainActor in
            isLoading = true

            // Load leads
            let leadsResult = await leadRepository.getNewLeads()
            switch leadsResult {
            case .success(let data):
                leads = data
                isLoading = false
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading:
                break
            }

            // Load clients
            let clientsResult = await clientRepository.getAllClients()
            if case .success(let data) = clientsResult {
                clients = data
            }

            // Load owners
            let ownersResult = await accountRepository.getAllManagerAndAdminUsers()
            if case .success(let data) = ownersResult {
                owners = data
            }
        }
    }

    func sortBy(_ column: String) {
        let ascending = (sortColumn == column) ? !sortAscending : true
        let sorted = leads.sorted { a, b in
            let valA: String
            let valB: String
            switch column {
            case "JobDescription": valA = a.jobDescription.lowercased(); valB = b.jobDescription.lowercased()
            case "OwnerName": valA = a.ownerName.lowercased(); valB = b.ownerName.lowercased()
            case "StatusName": valA = a.statusName.lowercased(); valB = b.statusName.lowercased()
            case "CostFromQuote":
                valA = String(format: "%020.2f", a.costFromQuote ?? 0.0)
                valB = String(format: "%020.2f", b.costFromQuote ?? 0.0)
            case "ClientName": valA = a.clientName.lowercased(); valB = b.clientName.lowercased()
            case "Location": valA = a.location.lowercased(); valB = b.location.lowercased()
            case "ContractTypeName": valA = a.contractTypeName.lowercased(); valB = b.contractTypeName.lowercased()
            case "CreatedDate": valA = a.createdDate ?? ""; valB = b.createdDate ?? ""
            default: valA = ""; valB = ""
            }
            return ascending ? valA < valB : valA > valB
        }
        leads = sorted
        sortColumn = column
        sortAscending = ascending
    }

    func startEdit(_ lead: LeadsDto, _ field: EditField) {
        let currentValue: String
        switch field {
        case .projectDescription: currentValue = lead.jobDescription
        case .owner: currentValue = lead.ownerId
        case .status: currentValue = "\(lead.statusId)"
        case .cost: currentValue = "\(lead.costFromQuote ?? 0.0)"
        case .client: currentValue = "\(lead.clientId ?? 0)"
        case .location: currentValue = lead.location
        case .contractType: currentValue = "\(lead.contractType ?? 0)"
        }
        editingLead = lead
        editField = field
        editValue = currentValue
        searchAddress = (field == .location) ? lead.location : ""
        placeList = []
        showPlaceList = false
    }

    func onEditValueChange(_ value: String) {
        editValue = value
    }

    func cancelEdit() {
        editingLead = nil
        editField = nil
        editValue = ""
        searchAddress = ""
        placeList = []
        showPlaceList = false
    }

    func saveEditorField() {
        guard let lead = editingLead, let field = editField else { return }
        var updatedLead = lead
        switch field {
        case .projectDescription:
            updatedLead.jobDescription = editValue
        case .cost:
            updatedLead.costFromQuote = Double(editValue)
        default:
            return
        }
        updateLead(updatedLead)
    }

    func selectLeadStatus(_ statusId: Int) {
        guard var lead = editingLead else { return }
        lead.statusId = statusId
        updateLead(lead)
    }

    func selectOwner(_ owner: UserDto) {
        guard var lead = editingLead else { return }
        lead.ownerId = owner.id
        lead.ownerName = owner.displayName
        updateLead(lead)
    }

    func selectClient(_ client: ClientDto) {
        guard var lead = editingLead else { return }
        lead.clientId = client.id
        lead.clientName = client.name
        lead.clientEmail = client.email
        updateLead(lead)
    }

    func selectContractType(_ contractTypeId: Int) {
        guard var lead = editingLead else { return }
        lead.contractType = contractTypeId
        updateLead(lead)
    }

    // Location search
    func onSearchAddressChange(_ value: String) {
        searchAddress = value
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            placeList = []
            showPlaceList = false
        } else {
            Task { @MainActor in
                let places = await googlePlacesService.getPlacesByText(searchText: value)
                placeList = places
                showPlaceList = !places.isEmpty
            }
        }
    }

    func clearSearchAddress() {
        searchAddress = ""
        placeList = []
        showPlaceList = false
    }

    func selectPlace(_ prediction: PlacePrediction) {
        Task { @MainActor in
            guard var lead = editingLead else { return }
            if let place = await googlePlacesService.getPlaceDetails(placeId: prediction.placeId) {
                lead.location = place.address
                lead.latitude = place.latitude
                lead.longitude = place.longitude
                searchAddress = place.address
                placeList = []
                showPlaceList = false
                updateLead(lead)
            }
        }
    }

    private func updateLead(_ lead: LeadsDto) {
        isUpdating = true
        editingLead = nil
        editField = nil
        editValue = ""
        searchAddress = ""
        placeList = []
        showPlaceList = false

        Task { @MainActor in
            let userId = preferencesManager.userId
            var updatedLead = lead
            updatedLead.modifiedBy = userId
            updatedLead.userId = userId
            updatedLead.basicAuthUid = preferencesManager.basicAuthUid

            let result = await leadRepository.updateLead(leadDetail: updatedLead)
            switch result {
            case .success:
                isUpdating = false
                successMessage = "Lead updated successfully"
                refresh()
            case .error(let message, _):
                isUpdating = false
                errorMessage = message
            case .loading:
                break
            }
        }
    }

    func formatDate(_ dateStr: String?) -> String {
        guard let dateStr = dateStr, !dateStr.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm"
        ]
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd MMM yyyy"
        let trimmed = dateStr.trimmingCharacters(in: .whitespaces)
        for fmt in formatters {
            let parser = DateFormatter()
            parser.dateFormat = fmt
            parser.locale = Locale(identifier: "en_US_POSIX")
            if let date = parser.date(from: trimmed) {
                return displayFormatter.string(from: date)
            }
        }
        // Try trimming fractional seconds
        let cleaned = trimmed.replacingOccurrences(of: "\\.\\d+$", with: "", options: .regularExpression)
        let parser = DateFormatter()
        parser.dateFormat = formatters[0]
        parser.locale = Locale(identifier: "en_US_POSIX")
        if let date = parser.date(from: cleaned) {
            return displayFormatter.string(from: date)
        }
        return dateStr
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = nil
    }

    // MARK: - Lead Status Colors matching MAUI exactly
    static func getLeadStatusColor(_ statusId: Int) -> Color {
        switch statusId {
        case 1: return Color(hex: "#FF9500")  // New Lead
        case 2: return Color(hex: "#5659E1")  // Quote Sent
        case 3: return Color(hex: "#00C874")  // Won
        case 4: return Color(hex: "#FFCB00")  // Contacted
        case 5: return Color(hex: "#808080")  // Quote Expired
        case 6: return Color(hex: "#800080")  // Drafted
        default: return Color(hex: "#808080")
        }
    }

    static func getContractTypeColor(_ contractType: Int?) -> Color {
        switch contractType {
        case 1: return Color(hex: "#C4C4C4")
        case 2: return Color(hex: "#BCA58A")
        case 3: return Color(hex: "#74AFCC")
        case 4: return Color(hex: "#CAB641")
        case 5: return Color(hex: "#175A63")
        case 6: return Color(hex: "#333333")
        case 7: return Color(hex: "#FF0000")
        case 8: return Color(hex: "#037F4C")
        case 9: return Color(hex: "#7F5347")
        case 10: return Color(hex: "#7F00FF")
        case 11: return Color(hex: "#FF8DA1")
        default: return Color(hex: "#C4C4C4")
        }
    }

    static let leadStatuses: [(Int, String)] = [
        (1, "New Lead"),
        (2, "Quote Sent"),
        (3, "Won"),
        (4, "Contacted"),
        (6, "Drafted")
    ]

    static let contractTypes: [(Int, String)] = [
        (1, "To Be Confirmed"),
        (2, "Full Contract"),
        (3, "Supply Place And Finish"),
        (4, "Place And Finish"),
        (5, "Labour Supply"),
        (6, "Box Place And Finish"),
        (7, "Remedial"),
        (8, "Supply Place Finish And Cut"),
        (9, "Place Finish And Cut"),
        (10, "Other Services"),
        (11, "Meetings")
    ]
}
