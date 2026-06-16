import Foundation

@Observable
class ForgotPasswordViewModel {
    // Step 1: Generate OTP
    var email: String = ""
    var emailError: String? = nil
    var otpSent: Bool = false

    // Step 2: Reset Password
    var otp: String = ""
    var newPassword: String = ""
    var confirmPassword: String = ""
    var otpError: String? = nil
    var passwordError: String? = nil
    var confirmPasswordError: String? = nil

    var isLoading: Bool = false
    var errorMessage: String? = nil
    var resetSuccess: Bool = false

    private let accountRepository: AccountRepository

    init(accountRepository: AccountRepository = DIContainer.shared.accountRepository) {
        self.accountRepository = accountRepository
    }

    func onEmailChange(_ value: String) {
        email = value
        emailError = nil
        errorMessage = nil
    }

    func onOtpChange(_ value: String) {
        otp = value
        otpError = nil
    }

    func onNewPasswordChange(_ value: String) {
        newPassword = value
        passwordError = nil
    }

    func onConfirmPasswordChange(_ value: String) {
        confirmPassword = value
        confirmPasswordError = nil
    }

    func generateOtp() {
        emailError = ValidationUtils.emailError(email)
        if emailError != nil { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            let result = await accountRepository.generateOtp(email: email.trimmingCharacters(in: .whitespaces))
            switch result {
            case .success:
                isLoading = false
                otpSent = true
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading:
                break
            }
        }
    }

    func resetPassword() {
        var hasError = false

        if otp.trimmingCharacters(in: .whitespaces).isEmpty {
            otpError = "OTP is required"; hasError = true
        }
        passwordError = ValidationUtils.passwordError(newPassword)
        if passwordError != nil { hasError = true }
        if confirmPassword != newPassword {
            confirmPasswordError = "Passwords do not match"; hasError = true
        }
        if hasError { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            let result = await accountRepository.forgotPassword(
                email: email.trimmingCharacters(in: .whitespaces),
                otp: otp.trimmingCharacters(in: .whitespaces),
                password: newPassword
            )
            switch result {
            case .success(let success):
                if success {
                    isLoading = false
                    resetSuccess = true
                } else {
                    isLoading = false
                    errorMessage = "Enter Correct OTP."
                }
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading:
                break
            }
        }
    }
}
