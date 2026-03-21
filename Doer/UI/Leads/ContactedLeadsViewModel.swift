import Foundation
import SwiftUI

@Observable
class ContactedLeadsViewModel {
    var isLoading: Bool = true
    var leads: [LeadsDto] = []
    var sortColumn: String = ""
    var sortAscending: Bool = true
    var errorMessage: String? = nil

    private let leadRepository: LeadRepository
    private var hasLoaded = false

    init(
        leadRepository: LeadRepository = DIContainer.shared.leadRepository
    ) {
        self.leadRepository = leadRepository
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

            let result = await leadRepository.getContactedLeads()
            switch result {
            case .success(let data):
                leads = data
                isLoading = false
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading:
                break
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
            case "ClientName": valA = a.clientName.lowercased(); valB = b.clientName.lowercased()
            case "ClientEmail": valA = a.clientEmail.lowercased(); valB = b.clientEmail.lowercased()
            case "CostFromQuote":
                valA = String(format: "%020.2f", a.costFromQuote ?? 0.0)
                valB = String(format: "%020.2f", b.costFromQuote ?? 0.0)
            case "Location": valA = a.location.lowercased(); valB = b.location.lowercased()
            case "CreatedDate": valA = a.createdDate ?? ""; valB = b.createdDate ?? ""
            default: valA = ""; valB = ""
            }
            return ascending ? valA < valB : valA > valB
        }
        leads = sorted
        sortColumn = column
        sortAscending = ascending
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

    func clearError() {
        errorMessage = nil
    }
}
