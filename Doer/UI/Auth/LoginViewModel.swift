import Foundation

@Observable
class LoginViewModel {
    var email: String = ""
    var password: String = ""
    var emailError: String? = nil
    var passwordError: String? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var loginSuccess: Bool = false

    private let accountRepository: AccountRepository
    private let preferencesManager: PreferencesManager
    private let secureStorageManager: SecureStorageManager

    init(
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager,
        secureStorageManager: SecureStorageManager = DIContainer.shared.secureStorageManager
    ) {
        self.accountRepository = accountRepository
        self.preferencesManager = preferencesManager
        self.secureStorageManager = secureStorageManager
    }

    func onEmailChange(_ value: String) {
        email = value
        emailError = nil
        errorMessage = nil
    }

    func onPasswordChange(_ value: String) {
        password = value
        passwordError = nil
        errorMessage = nil
    }

    func login() {
        var hasError = false

        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            emailError = "Email is required"
            hasError = true
        }
        if password.trimmingCharacters(in: .whitespaces).isEmpty {
            passwordError = "Password is required"
            hasError = true
        } else if password.count < 6 {
            passwordError = "Password must be at least 6 characters"
            hasError = true
        }
        if hasError { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                // Get FCM device token for push notifications
                let deviceToken = await FirebaseMessagingService.shared.getToken()

                let result = await accountRepository.authenticate(
                    userName: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    deviceToken: deviceToken
                )

                print("[LOGIN] Got result from authenticate")
                switch result {
                case .success(let user):
                    print("[LOGIN] Success - user: \(user.displayName), role: \(user.role), errorMessage: \(user.errorMessage ?? "nil")")
                    if let errMsg = user.errorMessage, !errMsg.isEmpty {
                        print("[LOGIN] User has errorMessage: \(errMsg)")
                        isLoading = false
                        errorMessage = errMsg
                        return
                    }

                    let role = user.role
                    print("[LOGIN] Role: \(role), adminVerified: \(user.adminVerified)")

                    // Only Contractor and Manager roles need admin approval
                    if role == "Contractor" && !user.adminVerified {
                        isLoading = false
                        errorMessage = "Your Account is not approved by the Administrator."
                        return
                    }
                    if role == "Manager" && !user.adminVerified {
                        isLoading = false
                        errorMessage = "Your Account is not approved by the Administrator."
                        return
                    }

                    let isAdmin = role.caseInsensitiveCompare("Administrator") == .orderedSame
                    let isManager = role.caseInsensitiveCompare("Manager") == .orderedSame
                    let isCaregiver = role.caseInsensitiveCompare("Contractor") == .orderedSame || role.caseInsensitiveCompare("Caregiver") == .orderedSame
                    let isCustomer = role.caseInsensitiveCompare("Customer") == .orderedSame

                    print("[LOGIN] Saving session - isAdmin: \(isAdmin), isManager: \(isManager), isCaregiver: \(isCaregiver)")
                    preferencesManager.saveUserSession(
                        fullName: user.displayName,
                        phone: user.phoneNumber,
                        email: user.email,
                        userId: user.id,
                        contactId: user.contactId,
                        basicAuthUid: user.token,
                        role: role,
                        isManager: isManager,
                        isCaregiver: isCaregiver,
                        isCustomer: isCustomer,
                        isAdmin: isAdmin,
                        isContractor: isCaregiver,
                        isEmployee: user.isEmployee
                    )

                    // Login response from the deployed API doesn't always carry IsEmployee
                    // correctly; GetUserById does. Refetch and overwrite after the session
                    // is saved so the auth interceptor can attach the bearer token.
                    if isCaregiver {
                        if case .success(let fullUser) = await accountRepository.getUser(id: user.id) {
                            preferencesManager.isEmployee = fullUser.isEmployee
                        }
                    }

                    secureStorageManager.isLoggedIn = true

                    isLoading = false
                    loginSuccess = true
                    print("[LOGIN] Login complete, loginSuccess = true")

                case .error(let message, _):
                    print("[LOGIN] Error: \(message ?? "nil")")
                    isLoading = false
                    errorMessage = (message.isEmpty == false)
                        ? message
                        : "Invalid email or password. Please try again."

                case .loading:
                    break
                }
            } catch {
                print("[LOGIN] Exception: \(error.localizedDescription)")
                isLoading = false
                errorMessage = error.localizedDescription.isEmpty
                    ? "Invalid email or password. Please try again."
                    : error.localizedDescription
            }
        }
    }
}
