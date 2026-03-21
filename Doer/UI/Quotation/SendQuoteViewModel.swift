import Foundation

@Observable
class SendQuoteViewModel {
    var isLoading: Bool = true
    var isSaving: Bool = false
    var quotedAmount: String = ""
    var notes: String = ""
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var isExistingQuote: Bool = false
    var existingQuoteId: Int = 0

    private let shiftId: Int
    private let shiftRepository: ShiftRepository
    private let preferencesManager: PreferencesManager
    private var hasLoaded = false

    init(
        shiftId: Int,
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        preferencesManager: PreferencesManager = PreferencesManager.shared
    ) {
        self.shiftId = shiftId
        self.shiftRepository = shiftRepository
        self.preferencesManager = preferencesManager
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadExistingQuote()
    }

    private func loadExistingQuote() {
        Task { @MainActor in
            let userId = preferencesManager.userId
            let result = await shiftRepository.getJobQuotationByContractorIdAndShiftId(contractorId: userId, shiftId: shiftId)
            switch result {
            case .success(let quote):
                if quote.id > 0 {
                    isLoading = false
                    quotedAmount = quote.quotedAmount > 0 ? String(quote.quotedAmount) : ""
                    notes = quote.notes
                    isExistingQuote = true
                    existingQuoteId = quote.id
                } else {
                    isLoading = false
                }
            case .error:
                isLoading = false
            case .loading: break
            }
        }
    }

    func updateQuotedAmount(_ amount: String) { quotedAmount = amount }
    func updateNotes(_ text: String) { notes = text }

    func submitQuote() {
        guard let amount = Double(quotedAmount), amount > 0 else {
            errorMessage = "Please enter a valid quoted amount"
            return
        }

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            let userId = preferencesManager.userId
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let nowUtc = formatter.string(from: Date())

            let quotation = JobQuotationDto(
                id: isExistingQuote ? existingQuoteId : 0,
                shiftId: shiftId,
                caregiverId: userId,
                quotedAmount: amount,
                quotedDate: nowUtc,
                status: "Created",
                notes: notes,
                createdBy: userId,
                createdDate: nowUtc,
                modifiedBy: userId,
                modifiedDate: nowUtc
            )

            let result = await shiftRepository.addJobQuotation(quotation: quotation)
            switch result {
            case .success:
                isSaving = false
                successMessage = "Job Quotation is submitted."
            case .error(let message, _):
                isSaving = false
                errorMessage = message ?? "Error in submitting Job Quote."
            case .loading: break
            }
        }
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }
}
