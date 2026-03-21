import Foundation

@Observable
class AllContractorsViewModel {
    var isLoading: Bool = true
    var contractors: [UserDto] = []
    var errorMessage: String? = nil
    var sortColumn: String = ""
    var sortAscending: Bool = true
    var searchName: String = ""
    var searchSkills: String = ""
    var searchAddress: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var placeList: [PlacePrediction] = []
    var showPlaceList: Bool = false
    var isFiltered: Bool = false
    var showFilterSheet: Bool = false

    private let accountRepository: AccountRepository
    private let googlePlacesService: GooglePlacesService
    private var hasLoaded = false

    private let displayDateFormat = "dd/MM/yyyy"
    private let parseFormats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm"
    ]

    init(
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService
    ) {
        self.accountRepository = accountRepository
        self.googlePlacesService = googlePlacesService
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadAllContractors()
    }

    // Matching MAUI: GetAllContractors -- ordered by Id descending, only AdminVerified
    private func loadAllContractors() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            let result = await accountRepository.getAllContractors()
            switch result {
            case .success(let data):
                let verified = data.filter { $0.adminVerified }
                let sorted = verified.sorted { ($0.id) > ($1.id) }
                contractors = sorted
                sortColumn = ""
                sortAscending = true
                isFiltered = false
                isLoading = false
            case .error(let message, _):
                errorMessage = message
                isLoading = false
            case .loading:
                break
            }
        }
    }

    func showFilter() {
        showFilterSheet = true
    }

    func dismissFilter() {
        showFilterSheet = false
    }

    func onSearchNameChanged(_ value: String) {
        searchName = value
    }

    func onSearchSkillsChanged(_ value: String) {
        searchSkills = value
    }

    func onSearchAddressChanged(_ value: String) {
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

    func selectPlace(_ prediction: PlacePrediction) {
        Task { @MainActor in
            if let place = await googlePlacesService.getPlaceDetails(placeId: prediction.placeId) {
                searchAddress = place.address
                latitude = place.latitude
                longitude = place.longitude
                placeList = []
                showPlaceList = false
            } else {
                placeList = []
                showPlaceList = false
            }
        }
    }

    func clearSearchLocation() {
        searchAddress = ""
        latitude = 0.0
        longitude = 0.0
        loadAllContractors()
    }

    func applyFilter() {
        showFilterSheet = false
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            let result = await accountRepository.searchContractorsBySkillsAndLocation(
                latitude: latitude,
                longitude: longitude,
                searchSkills: searchSkills,
                searchName: searchName
            )
            switch result {
            case .success(let data):
                let verified = data.filter { $0.adminVerified }
                contractors = verified
                sortColumn = ""
                sortAscending = true
                isFiltered = true
                isLoading = false
            case .error(let message, _):
                errorMessage = message
                isLoading = false
            case .loading:
                break
            }
        }
    }

    func clearFilter() {
        searchName = ""
        searchSkills = ""
        searchAddress = ""
        latitude = 0.0
        longitude = 0.0
        isFiltered = false
        showFilterSheet = false
        loadAllContractors()
    }

    func sortBy(_ column: String) {
        let ascending = (sortColumn == column) ? !sortAscending : true
        let sorted = contractors.sorted { a, b in
            let valA: String
            let valB: String
            switch column {
            case "DisplayName": valA = a.displayName.lowercased(); valB = b.displayName.lowercased()
            case "Email": valA = a.email.lowercased(); valB = b.email.lowercased()
            case "PhoneNumber": valA = a.phoneNumber.lowercased(); valB = b.phoneNumber.lowercased()
            case "DateofBirthString": valA = a.dateOfBirth ?? ""; valB = b.dateOfBirth ?? ""
            case "Address": valA = a.address.lowercased(); valB = b.address.lowercased()
            case "WorkExperience": valA = a.workExperience.lowercased(); valB = b.workExperience.lowercased()
            case "Skills": valA = a.skills.lowercased(); valB = b.skills.lowercased()
            default: valA = ""; valB = ""
            }
            return ascending ? (valA < valB) : (valA > valB)
        }
        contractors = sorted
        sortColumn = column
        sortAscending = ascending
    }

    func formatDateOfBirth(_ dateStr: String?) -> String {
        guard let dateStr = dateStr, !dateStr.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for fmt in parseFormats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: dateStr.trimmingCharacters(in: .whitespaces)) {
                formatter.dateFormat = displayDateFormat
                return formatter.string(from: date)
            }
        }
        // Fallback: trim fractional seconds
        let trimmed = dateStr.replacingOccurrences(of: "\\.\\d+$", with: "", options: .regularExpression)
        formatter.dateFormat = parseFormats[0]
        if let date = formatter.date(from: trimmed) {
            formatter.dateFormat = displayDateFormat
            return formatter.string(from: date)
        }
        return dateStr
    }

    func clearError() {
        errorMessage = nil
    }
}
