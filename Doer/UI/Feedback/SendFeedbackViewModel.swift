import Foundation

@Observable
class SendFeedbackViewModel {
    var isLoading: Bool = true
    var isSaving: Bool = false
    var feedbackText: String = ""
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
                isLoading = false
                feedbackText = ""
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    func updateFeedback(_ text: String) { feedbackText = text }

    func submitFeedback() {
        guard let shift = currentShift else { return }
        let feedback = feedbackText.trimmingCharacters(in: .whitespaces)
        guard !feedback.isEmpty else {
            errorMessage = "Please enter feedback"
            return
        }

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            let userId = preferencesManager.userId
            var updatedShift = shift
            updatedShift.feedback = feedback
            updatedShift.modifiedBy = userId
            updatedShift.statusId = 8 // FinishJob

            let result = await shiftRepository.updateShift(shiftDetail: updatedShift)
            switch result {
            case .success:
                isSaving = false
                successMessage = "Job Completed"
            case .error(let message, _):
                isSaving = false
                errorMessage = (message ?? "").isEmpty ? "There was a problem in Completing Job" : message
            case .loading: break
            }
        }
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }
}
