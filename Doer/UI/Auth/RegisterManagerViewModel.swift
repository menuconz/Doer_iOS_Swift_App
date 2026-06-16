import Foundation

@Observable
class RegisterManagerViewModel {
    var fullName: String = ""
    var email: String = ""
    var phone: String = ""
    var dateOfBirth: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var nameError: String? = nil
    var emailError: String? = nil
    var phoneError: String? = nil
    var dobError: String? = nil
    var passwordError: String? = nil
    var confirmPasswordError: String? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var showDatePicker: Bool = false
    var selectedDate: Date = {
        let calendar = Calendar.current
        return calendar.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    }()

    private let accountRepository: AccountRepository

    init(accountRepository: AccountRepository = DIContainer.shared.accountRepository) {
        self.accountRepository = accountRepository
    }

    func onNameChange(_ value: String) { fullName = value; nameError = nil }
    func onEmailChange(_ value: String) { email = value; emailError = nil }
    func onPhoneChange(_ value: String) { phone = value; phoneError = nil }
    func onDateOfBirthChange(_ value: String) { dateOfBirth = value }
    func onPasswordChange(_ value: String) { password = value; passwordError = nil }
    func onConfirmPasswordChange(_ value: String) { confirmPassword = value; confirmPasswordError = nil }

    func onDateSelected(_ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        dateOfBirth = formatter.string(from: date)
        selectedDate = date
        dobError = ValidationUtils.dateOfBirthError(date)
        showDatePicker = false
    }

    func register() {
        // Run all field validations up front so every problem is shown at once.
        nameError = ValidationUtils.nameError(fullName, fieldName: "Full name")
        emailError = ValidationUtils.emailError(email)
        phoneError = ValidationUtils.phoneError(phone)            // phone is optional here
        dobError = dateOfBirth.isEmpty ? nil : ValidationUtils.dateOfBirthError(selectedDate)
        passwordError = ValidationUtils.passwordError(password)
        confirmPasswordError = (confirmPassword != password) ? "Passwords do not match" : nil

        let hasError = [nameError, emailError, phoneError, dobError, passwordError, confirmPasswordError]
            .contains { $0 != nil }
        if hasError { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                // Check if email exists
                let emailCheck = await accountRepository.checkEmailExists(email: email.trimmingCharacters(in: .whitespaces))
                switch emailCheck {
                case .success(let exists):
                    if exists {
                        isLoading = false
                        emailError = "Email already registered"
                        return
                    }
                case .error(let message, _):
                    isLoading = false
                    errorMessage = message
                    return
                case .loading:
                    break
                }

                // Convert dd/MM/yyyy to ISO format for API
                var isoDateOfBirth: String? = nil
                if !dateOfBirth.isEmpty {
                    let parts = dateOfBirth.split(separator: "/")
                    if parts.count == 3 {
                        isoDateOfBirth = "\(parts[2])-\(parts[1])-\(parts[0])T00:00:00"
                    }
                }

                let registerUser = RegisterUserWithoutDocumentDto(
                    displayName: fullName.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    restHomeId: 0,
                    dateOfBirth: isoDateOfBirth,
                    phoneNumber: phone.trimmingCharacters(in: .whitespaces)
                )

                let result = await accountRepository.registerManager(registerUser: registerUser)
                switch result {
                case .success:
                    isLoading = false
                    successMessage = "Your account as Manager has been successfully created and is pending approval"
                case .error(let message, _):
                    isLoading = false
                    errorMessage = message
                case .loading:
                    break
                }
            } catch {
                isLoading = false
                errorMessage = "Registration failed. Please try again."
            }
        }
    }
}
