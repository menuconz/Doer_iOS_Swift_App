import Foundation
import SwiftUI
import UIKit

struct SectionState {
    var leads: [LeadsDto] = []
    var isExpanded: Bool = true
    var sortColumn: String = ""
    var sortAscending: Bool = true
}

enum QuotedSection {
    case quoteNotAccepted, closedDeal, quoteExpired, drafted
}

@Observable
class QuotedLeadsViewModel {
    var isLoading: Bool = true
    var quoteNotAccepted = SectionState()   // statusId = 2
    var closedDeal = SectionState()          // statusId = 3
    var quoteExpired = SectionState()        // statusId = 5
    var drafted = SectionState()             // statusId = 6
    var clients: [ClientDto] = []
    var owners: [UserDto] = []
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

    // Cache-aware accessors
    func leadStatusColor(_ statusId: Int) -> Color {
        let argb = boardConfigCache.color(
            "LeadStatus", value: statusId,
            fallback: argbFromColor(NewLeadsViewModel.getLeadStatusColor(statusId))
        )
        return Color(argb: argb)
    }

    func contractTypeColorDynamic(_ contractType: Int?) -> Color {
        let argb = boardConfigCache.color(
            "ContractType", value: contractType ?? -1,
            fallback: argbFromColor(NewLeadsViewModel.getContractTypeColor(contractType))
        )
        return Color(argb: argb)
    }

    private func argbFromColor(_ c: Color) -> UInt32 {
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt32((a * 255).rounded()) & 0xFF) << 24
            | (UInt32((r * 255).rounded()) & 0xFF) << 16
            | (UInt32((g * 255).rounded()) & 0xFF) << 8
            |  UInt32((b * 255).rounded()) & 0xFF
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

            let leadsResult = await leadRepository.getQuotedAndWonLeads()
            switch leadsResult {
            case .success(let allLeads):
                quoteNotAccepted.leads = allLeads.filter { $0.statusId == 2 }
                closedDeal.leads = allLeads.filter { $0.statusId == 3 }
                quoteExpired.leads = allLeads.filter { $0.statusId == 5 }
                drafted.leads = allLeads.filter { $0.statusId == 6 }
                isLoading = false
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading:
                break
            }

            let clientsResult = await clientRepository.getAllClients()
            if case .success(let data) = clientsResult {
                clients = data
            }

            let ownersResult = await accountRepository.getAllManagerAndAdminUsers()
            if case .success(let data) = ownersResult {
                owners = data
            }
        }
    }

    func toggleSection(_ section: QuotedSection) {
        switch section {
        case .quoteNotAccepted: quoteNotAccepted.isExpanded.toggle()
        case .closedDeal: closedDeal.isExpanded.toggle()
        case .quoteExpired: quoteExpired.isExpanded.toggle()
        case .drafted: drafted.isExpanded.toggle()
        }
    }

    func sortSection(_ section: QuotedSection, _ column: String) {
        var sectionState: SectionState
        switch section {
        case .quoteNotAccepted: sectionState = quoteNotAccepted
        case .closedDeal: sectionState = closedDeal
        case .quoteExpired: sectionState = quoteExpired
        case .drafted: sectionState = drafted
        }

        let ascending = (sectionState.sortColumn == column) ? !sectionState.sortAscending : true
        let sorted = sectionState.leads.sorted { a, b in
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

        sectionState.leads = sorted
        sectionState.sortColumn = column
        sectionState.sortAscending = ascending

        switch section {
        case .quoteNotAccepted: quoteNotAccepted = sectionState
        case .closedDeal: closedDeal = sectionState
        case .quoteExpired: quoteExpired = sectionState
        case .drafted: drafted = sectionState
        }
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

    func sendFollowUp(_ leadId: Int) {
        isUpdating = true
        Task { @MainActor in
            let result = await leadRepository.sendFollowUpMailToClient(id: leadId)
            switch result {
            case .success:
                isUpdating = false
                successMessage = "Follow up email sent successfully."
            case .error(let message, _):
                isUpdating = false
                errorMessage = message.isEmpty ? "Failed to send follow up email. Please try again." : message
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
        let cleaned = trimmed.replacingOccurrences(of: "\\.\\d+$", with: "", options: .regularExpression)
        let parser = DateFormatter()
        parser.dateFormat = formatters[0]
        parser.locale = Locale(identifier: "en_US_POSIX")
        if let date = parser.date(from: cleaned) {
            return displayFormatter.string(from: date)
        }
        return dateStr
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }

    static let quotedLeadStatuses: [(Int, String)] = [
        (1, "New Lead"),
        (2, "Quote Sent"),
        (3, "Won"),
        (4, "Contacted"),
        (5, "Quote Expired")
    ]
}
