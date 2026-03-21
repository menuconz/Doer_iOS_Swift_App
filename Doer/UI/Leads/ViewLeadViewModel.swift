import Foundation
import SwiftUI

@Observable
class ViewLeadViewModel {
    var isLoading: Bool = true
    var lead: LeadsDto? = nil
    var errorMessage: String? = nil
    var isNew: Bool = false
    var isQuoted: Bool = false
    var isWon: Bool = false
    var isContacted: Bool = false
    var canUpdate: Bool = false
    var isReadOnly: Bool = true
    var isActionLoading: Bool = false
    var toastMessage: String? = nil
    var shouldNavigateBack: Bool = false

    private let leadRepository: LeadRepository
    private let preferencesManager: PreferencesManager
    private let leadId: Int
    private var hasLoaded = false

    init(
        leadId: Int,
        leadRepository: LeadRepository = DIContainer.shared.leadRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager
    ) {
        self.leadId = leadId
        self.leadRepository = leadRepository
        self.preferencesManager = preferencesManager
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadLead()
    }

    private func loadLead() {
        Task { @MainActor in
            isLoading = true

            let foundLead = await findLeadById(leadId)

            if let foundLead = foundLead {
                lead = foundLead

                // Matching MAUI OnNavigatedTo() status flag logic exactly
                switch foundLead.statusId {
                case LeadStatus.newLead.rawValue:
                    isNew = true
                    canUpdate = true
                    isReadOnly = false
                case LeadStatus.quoteSent.rawValue:
                    isQuoted = true
                case LeadStatus.won.rawValue:
                    isWon = true
                case LeadStatus.contacted.rawValue:
                    isContacted = true
                default:
                    break
                }

                isLoading = false
            } else {
                isLoading = false
                errorMessage = "Lead not found"
            }
        }
    }

    private func findLeadById(_ id: Int) async -> LeadsDto? {
        // Try new leads first
        let newResult = await leadRepository.getNewLeads()
        if case .success(let data) = newResult {
            if let found = data.first(where: { $0.id == id }) { return found }
        }

        // Try quoted and won leads
        let quotedResult = await leadRepository.getQuotedAndWonLeads()
        if case .success(let data) = quotedResult {
            if let found = data.first(where: { $0.id == id }) { return found }
        }

        // Try contacted leads
        let contactedResult = await leadRepository.getContactedLeads()
        if case .success(let data) = contactedResult {
            if let found = data.first(where: { $0.id == id }) { return found }
        }

        return nil
    }

    // Send Quote
    func sendQuote() {
        guard let lead = lead else { return }

        // Validate required fields
        var missingFields: [String] = []
        if lead.clientName.trimmingCharacters(in: .whitespaces).isEmpty { missingFields.append("Client Name") }
        if lead.clientEmail.trimmingCharacters(in: .whitespaces).isEmpty { missingFields.append("Client Email") }
        if lead.costFromQuote == nil || (lead.costFromQuote ?? 0) <= 0 { missingFields.append("Cost From Quote") }

        if !missingFields.isEmpty {
            toastMessage = "Please enter \(missingFields.joined(separator: ", ")) before sending the quote"
            return
        }

        isActionLoading = true
        Task { @MainActor in
            do {
                let userId = preferencesManager.userId
                var updatedLead = lead
                updatedLead.statusId = LeadStatus.quoteSent.rawValue
                updatedLead.modifiedBy = userId

                let result = await leadRepository.updateLead(leadDetail: updatedLead)
                switch result {
                case .success:
                    toastMessage = "Quote Sent Sucessfully"
                    shouldNavigateBack = true
                case .error(let message, _):
                    toastMessage = message.isEmpty ? "There was a problem in Sent Quote" : message
                case .loading:
                    break
                }
            }
            isActionLoading = false
        }
    }

    // Close Deal (Won)
    func closeDeal() {
        guard let lead = lead else { return }

        var missingFields: [String] = []
        if lead.clientName.trimmingCharacters(in: .whitespaces).isEmpty { missingFields.append("Client Name") }
        if lead.clientEmail.trimmingCharacters(in: .whitespaces).isEmpty { missingFields.append("Client Email") }
        if lead.costFromQuote == nil || (lead.costFromQuote ?? 0) <= 0 { missingFields.append("Cost From Quote") }

        if !missingFields.isEmpty {
            toastMessage = "Please enter \(missingFields.joined(separator: ", ")) before sending the quote"
            return
        }

        isActionLoading = true
        Task { @MainActor in
            let userId = preferencesManager.userId
            var updatedLead = lead
            updatedLead.statusId = LeadStatus.won.rawValue
            updatedLead.modifiedBy = userId

            let result = await leadRepository.updateLead(leadDetail: updatedLead)
            switch result {
            case .success:
                toastMessage = "Status Updated to Won"
                shouldNavigateBack = true
            case .error(let message, _):
                toastMessage = message.isEmpty ? "There was a problem in Update Status to Won" : message
            case .loading:
                break
            }
            isActionLoading = false
        }
    }

    // Move to Contacts
    func moveToContacts() {
        guard let lead = lead else { return }

        isActionLoading = true
        Task { @MainActor in
            let userId = preferencesManager.userId
            var updatedLead = lead
            updatedLead.statusId = LeadStatus.contacted.rawValue
            updatedLead.modifiedBy = userId

            let result = await leadRepository.updateLead(leadDetail: updatedLead)
            switch result {
            case .success:
                toastMessage = "Status Updated to Contacted"
                shouldNavigateBack = true
            case .error(let message, _):
                toastMessage = message.isEmpty ? "There was a problem in Update Status to Contacted" : message
            case .loading:
                break
            }
            isActionLoading = false
        }
    }

    // Update Lead
    func updateLead() {
        guard let lead = lead else { return }

        isActionLoading = true
        Task { @MainActor in
            let userId = preferencesManager.userId
            var updatedLead = lead
            updatedLead.modifiedBy = userId

            let result = await leadRepository.updateLead(leadDetail: updatedLead)
            switch result {
            case .success:
                toastMessage = "Lead Details Updated Sucessfully"
                shouldNavigateBack = true
            case .error(let message, _):
                toastMessage = message.isEmpty ? "There was a problem in Updating Lead Details" : message
            case .loading:
                break
            }
            isActionLoading = false
        }
    }
}
