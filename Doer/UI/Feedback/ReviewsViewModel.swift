import Foundation

@Observable
class ReviewsViewModel {
    var isLoading: Bool = true
    var isSaving: Bool = false
    var managerFeedback: String = ""
    var hasManagerFeedback: Bool = false
    var replyText: String = ""
    var hasExistingReply: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil

    private let shiftId: Int
    private var currentShift: ShiftDto? = nil
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
        loadShift()
    }

    private func loadShift() {
        Task { @MainActor in
            let result = await shiftRepository.getShiftById(id: shiftId)
            switch result {
            case .success(let shift):
                currentShift = shift
                let existingReply = shift.contractorResponseToReview ?? ""
                isLoading = false
                managerFeedback = shift.feedback
                hasManagerFeedback = !shift.feedback.isEmpty
                replyText = existingReply
                hasExistingReply = !existingReply.isEmpty
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    func updateReplyText(_ text: String) { replyText = text }

    func submitReply() {
        guard let shift = currentShift else { return }
        let reply = replyText.trimmingCharacters(in: .whitespaces)
        guard !reply.isEmpty else {
            errorMessage = "Please enter a reply"
            return
        }

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            let userId = preferencesManager.userId
            var updatedShift = shift
            updatedShift.contractorResponseToReview = reply
            updatedShift.modifiedBy = userId

            let result = await shiftRepository.updateShift(shiftDetail: updatedShift)
            switch result {
            case .success(let data):
                currentShift = data
                isSaving = false
                hasExistingReply = true
                successMessage = "Submit Successfully"
            case .error(let message, _):
                isSaving = false
                errorMessage = message ?? "There was a problem in Submitting Review"
            case .loading: break
            }
        }
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }
}
