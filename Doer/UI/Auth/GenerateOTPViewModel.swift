import Foundation

@Observable
class GenerateOTPViewModel {
    var email: String = ""
    var emailError: String? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var otpGenerated: Bool = false

    private let accountRepository: AccountRepository

    init(accountRepository: AccountRepository = DIContainer.shared.accountRepository) {
        self.accountRepository = accountRepository
    }

    func onEmailChange(_ value: String) {
        email = value
        emailError = nil
        errorMessage = nil
    }

    func generateOtp() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        if trimmedEmail.isEmpty {
            emailError = "Email is required"
            return
        }

        if !isValidEmail(trimmedEmail) {
            emailError = "Please enter a valid email address"
            return
        }

        isLoading = true
        errorMessage = nil
        emailError = nil

        Task { @MainActor in
            let result = await accountRepository.generateOtp(email: trimmedEmail)
            switch result {
            case .success:
                isLoading = false
                otpGenerated = true
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading:
                break
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}
