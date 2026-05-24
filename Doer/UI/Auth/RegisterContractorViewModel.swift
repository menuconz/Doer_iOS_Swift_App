import Foundation

@Observable
class RegisterContractorViewModel {
    var fullName: String = ""
    var email: String = ""
    var phone: String = ""
    var dateOfBirth: String = ""
    var searchAddress: String = ""
    var address: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var password: String = ""
    var confirmPassword: String = ""
    var nameError: String? = nil
    var emailError: String? = nil
    var passwordError: String? = nil
    var confirmPasswordError: String? = nil
    var documents: [(data: Data, fileName: String)] = []
    var placeSuggestions: [PlacePrediction] = []
    var showSuggestions: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var showDatePicker: Bool = false
    var selectedDate: Date = {
        let calendar = Calendar.current
        return calendar.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    }()

    private let accountRepository: AccountRepository
    private let googlePlacesService: GooglePlacesService
    private var searchTask: Task<Void, Never>?

    init(
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService
    ) {
        self.accountRepository = accountRepository
        self.googlePlacesService = googlePlacesService
    }

    func onNameChange(_ value: String) { fullName = value; nameError = nil }
    func onEmailChange(_ value: String) { email = value; emailError = nil }
    func onPhoneChange(_ value: String) { phone = value }
    func onDateOfBirthChange(_ value: String) { dateOfBirth = value }
    func onPasswordChange(_ value: String) { password = value; passwordError = nil }
    func onConfirmPasswordChange(_ value: String) { confirmPassword = value; confirmPasswordError = nil }

    func onDateSelected(_ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        dateOfBirth = formatter.string(from: date)
        selectedDate = date
        showDatePicker = false
    }

    func onSearchAddressChange(_ value: String) {
        searchAddress = value
        if value.count >= 3 && value != address {
            searchTask?.cancel()
            searchTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                if Task.isCancelled { return }
                let predictions = await googlePlacesService.getPlacesByText(searchText: value)
                placeSuggestions = predictions
                showSuggestions = !predictions.isEmpty
            }
        } else {
            showSuggestions = false
            placeSuggestions = []
        }
    }

    func onPlaceSelected(_ prediction: PlacePrediction) {
        Task { @MainActor in
            if let place = await googlePlacesService.getPlaceDetails(placeId: prediction.placeId) {
                address = place.address
                searchAddress = place.address
                latitude = place.latitude
                longitude = place.longitude
                showSuggestions = false
                placeSuggestions = []
            }
        }
    }

    func addDocument(data: Data, fileName: String) {
        documents.append((data: data, fileName: fileName))
    }

    func removeDocument(at index: Int) {
        guard index >= 0 && index < documents.count else { return }
        documents.remove(at: index)
    }

    func register() {
        var hasError = false

        if fullName.trimmingCharacters(in: .whitespaces).isEmpty {
            nameError = "Name is required"; hasError = true
        }
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            emailError = "Email is required"; hasError = true
        } else if !isValidEmail(email) {
            emailError = "Invalid email format"; hasError = true
        }
        if password.trimmingCharacters(in: .whitespaces).isEmpty {
            passwordError = "Password is required"; hasError = true
        } else if password.count < 6 {
            passwordError = "Password must be at least 6 characters"; hasError = true
        }
        if confirmPassword != password {
            confirmPasswordError = "Passwords do not match"; hasError = true
        }
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

                let deviceToken = await FirebaseMessagingService.shared.getToken()

                let user = UserDto(
                    displayName: fullName.trimmingCharacters(in: .whitespaces),
                    phoneNumber: phone.trimmingCharacters(in: .whitespaces),
                    password: password,
                    email: email.trimmingCharacters(in: .whitespaces),
                    deviceToken: deviceToken,
                    deviceTypeId: Constants.deviceTypeIOS,
                    address: searchAddress,
                    latitude: latitude,
                    longitude: longitude,
                    dateOfBirthString: dateOfBirth
                )

                let result = await accountRepository.registerContractor(user: user, documentFiles: documents)
                switch result {
                case .success:
                    isLoading = false
                    successMessage = "Thank you for registering with us! Your account as Contractor has been successfully created and is pending approval from an administrator. You will receive an email notification once your account has been approved. Thank you for your patience."
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

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}
