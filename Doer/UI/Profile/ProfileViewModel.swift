import Foundation

@Observable
class ProfileViewModel {
    var isLoading: Bool = true
    var user: UserDto? = nil
    var isCaregiver: Bool = false
    var isCustomer: Bool = false
    var isManager: Bool = false
    var isNoDocument: Bool = false
    var errorMessage: String? = nil
    var isDeleting: Bool = false
    var isDeleted: Bool = false
    var deleteSuccessMessage: String? = nil

    private let accountRepository: AccountRepository
    private let preferencesManager: PreferencesManager
    private var hasLoaded = false

    init(
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        preferencesManager: PreferencesManager = PreferencesManager.shared
    ) {
        self.accountRepository = accountRepository
        self.preferencesManager = preferencesManager
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadProfile()
    }

    private func loadProfile() {
        Task { @MainActor in
            let userId = preferencesManager.userId
            let isCg = preferencesManager.isCaregiver
            let isCust = preferencesManager.isCustomer
            let isMgr = preferencesManager.isManager

            let result = await accountRepository.getUser(id: userId)
            switch result {
            case .success(let userData):
                let isNoDoc = isCg ? (userData.documents?.isEmpty ?? true) : false
                isLoading = false
                user = userData
                isCaregiver = isCg
                isCustomer = isCust
                isManager = isMgr
                isNoDocument = isNoDoc
            case .error(let message, _):
                isLoading = false
                errorMessage = message ?? "Error"
            case .loading: break
            }
        }
    }

    func deleteAccount() {
        Task { @MainActor in
            isDeleting = true
            let userId = preferencesManager.userId
            let result = await accountRepository.deleteUserAccount(userId: userId)
            switch result {
            case .success:
                preferencesManager.clearSession()
                isDeleting = false
                deleteSuccessMessage = "Your account has been successfully deleted. We appreciate your time with us and hope to serve you again in the future."
            case .error:
                isDeleting = false
                errorMessage = "Error deleting account. Please try again later."
            case .loading: break
            }
        }
    }

    func onDeleteSuccessDismissed() {
        deleteSuccessMessage = nil
        isDeleted = true
    }

    func refresh() { loadProfile() }
    func clearError() { errorMessage = nil }
}
