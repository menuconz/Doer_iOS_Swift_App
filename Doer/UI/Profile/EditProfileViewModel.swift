import Foundation

@Observable
class EditProfileViewModel {
    var isLoading: Bool = true
    var isSaving: Bool = false
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    var dateOfBirth: String = ""
    var dateOfBirthRaw: String? = nil
    var address: String = ""
    var workExperience: String = ""
    var skills: String = ""
    var isCaregiver: Bool = false
    var isCustomer: Bool = false
    var isManager: Bool = false
    var isNoDocument: Bool = false
    var hasDocument: Bool = false
    var existingDocuments: [FileModelDto] = []
    var newDocuments: [(data: Data, fileName: String)] = []
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var userId: String = ""
    var searchAddress: String = ""
    var placeList: [PlacePrediction] = []
    var showPlaceList: Bool = false
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var restHomeId: Int? = nil

    private let accountRepository: AccountRepository
    private let preferencesManager: PreferencesManager
    private let googlePlacesService: GooglePlacesService
    private var hasLoaded = false

    init(
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        preferencesManager: PreferencesManager = PreferencesManager.shared,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService
    ) {
        self.accountRepository = accountRepository
        self.preferencesManager = preferencesManager
        self.googlePlacesService = googlePlacesService
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadProfile()
    }

    private func loadProfile() {
        Task { @MainActor in
            let uid = preferencesManager.userId
            let isCg = preferencesManager.isCaregiver
            let isCust = preferencesManager.isCustomer
            let isMgr = preferencesManager.isManager

            let result = await accountRepository.getUser(id: uid)
            switch result {
            case .success(let user):
                let isNoDoc = isCg ? (user.documents?.isEmpty ?? true) : false
                let hasDocs = isCg ? !(user.documents?.isEmpty ?? true) : false

                isLoading = false
                name = user.displayName
                email = user.email
                phone = user.phoneNumber
                dateOfBirth = formatDobForDisplay(user.dateOfBirth)
                dateOfBirthRaw = user.dateOfBirth
                searchAddress = user.address
                address = user.address
                latitude = user.latitude ?? 0.0
                longitude = user.longitude ?? 0.0
                workExperience = user.workExperience
                skills = user.skills
                isCaregiver = isCg
                isCustomer = isCust
                isManager = isMgr
                isNoDocument = isNoDoc
                hasDocument = hasDocs
                existingDocuments = user.documents ?? []
                userId = uid
                restHomeId = user.restHomeId
            case .error(let message, _):
                isLoading = false
                errorMessage = message ?? "Error"
            case .loading: break
            }
        }
    }

    func updateDateOfBirth(_ dob: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yyyy"
        var isoDate = dob
        if let date = formatter.date(from: dob) {
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            isoDate = formatter.string(from: date)
        }
        dateOfBirth = dob
        dateOfBirthRaw = isoDate
    }

    func updateDateOfBirthFromPicker(_ date: Date) {
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.dateFormat = "dd/MM/yyyy"
        let isoFormatter = DateFormatter()
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateOfBirth = displayFormatter.string(from: date)
        dateOfBirthRaw = isoFormatter.string(from: date)
    }

    // Google Places - matching MAUI OnSearchAddressChanged + GetSearchList
    func onSearchAddressChange(_ value: String) {
        searchAddress = value
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            placeList = []
            showPlaceList = false
        } else {
            Task { @MainActor in
                let places = await googlePlacesService.getPlacesByText(searchText: value)
                placeList = places
                showPlaceList = !places.isEmpty
            }
        }
    }

    // Matching MAUI Select + AutoFillSelectedAddress
    func selectPlace(_ prediction: PlacePrediction) {
        Task { @MainActor in
            if let place = await googlePlacesService.getPlaceDetails(placeId: prediction.placeId) {
                address = place.address
                searchAddress = place.address
                latitude = place.latitude
                longitude = place.longitude
                placeList = []
                showPlaceList = false
            } else {
                showPlaceList = false
                placeList = []
            }
        }
    }

    func addDocument(data: Data, fileName: String) {
        newDocuments.append((data: data, fileName: fileName))
    }

    func removeNewDocument(at index: Int) {
        guard index >= 0 && index < newDocuments.count else { return }
        newDocuments.remove(at: index)
    }

    // Matching MAUI DeleteDocument command
    func deleteExistingDocument(_ doc: FileModelDto) {
        Task { @MainActor in
            isLoading = true
            let result = await accountRepository.deleteDocument(id: doc.id)
            switch result {
            case .success:
                existingDocuments.removeAll { $0.id == doc.id }
                isNoDocument = existingDocuments.isEmpty
                hasDocument = !existingDocuments.isEmpty
                isLoading = false
                successMessage = "Document Deleted Sucessfully"
            case .error:
                isLoading = false
                errorMessage = "There was a problem in Deleting Document"
            case .loading: break
            }
        }
    }

    // Matching MAUI UpdateProfilePage command
    func saveProfile() {
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            let user = UserDto(
                displayName: name,
                id: userId,
                username: email.trimmingCharacters(in: .whitespaces),
                phoneNumber: phone,
                dateOfBirth: dateOfBirthRaw,
                email: email.trimmingCharacters(in: .whitespaces),
                address: searchAddress,
                latitude: latitude,
                longitude: longitude,
                workExperience: isCaregiver ? workExperience : "",
                skills: isCaregiver ? skills : ""
            )

            let result = await accountRepository.updateProfile(user: user, newDocuments: newDocuments)
            switch result {
            case .success:
                isSaving = false
                successMessage = "Profile Updated Sucessfully"
            case .error(let message, _):
                isSaving = false
                errorMessage = message ?? "There was a problem in Updating Profile"
            case .loading: break
            }
        }
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }

    private func formatDobForDisplay(_ dob: String?) -> String {
        guard let dob = dob, !dob.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let cleaned = dob.components(separatedBy: "T").first ?? dob
        if let date = formatter.date(from: cleaned) {
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
        return dob
    }
}
