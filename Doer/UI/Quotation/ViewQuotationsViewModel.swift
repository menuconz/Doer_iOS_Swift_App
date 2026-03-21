import Foundation

@Observable
class ViewQuotationsViewModel {
    var isLoading: Bool = true
    var isHiring: Bool = false
    var quotations: [JobQuotationDto] = []
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var isHired: Bool = false
    var sortColumn: String = ""
    var sortAscending: Bool = true
    var searchSkills: String = ""
    var searchName: String = ""
    var searchAddress: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var placeList: [PlacePrediction] = []
    var showPlaceList: Bool = false
    var showFilterSheet: Bool = false

    private let shiftId: Int
    private var shift: ShiftDto? = nil
    private let shiftRepository: ShiftRepository
    private let preferencesManager: PreferencesManager
    private let googlePlacesService: GooglePlacesService
    private var hasLoaded = false

    private let parseFormats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm"
    ]

    init(
        shiftId: Int,
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        preferencesManager: PreferencesManager = PreferencesManager.shared,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService
    ) {
        self.shiftId = shiftId
        self.shiftRepository = shiftRepository
        self.preferencesManager = preferencesManager
        self.googlePlacesService = googlePlacesService
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadData()
    }

    private func loadData() {
        Task { @MainActor in
            isLoading = true

            let shiftResult = await shiftRepository.getShiftById(id: shiftId)
            if case .success(let s) = shiftResult { shift = s }

            let result = await shiftRepository.getQuotationsByJobId(id: shiftId)
            switch result {
            case .success(let data):
                if data.isEmpty {
                    isLoading = false
                    quotations = []
                    errorMessage = "No Quotation found, Please try again later."
                } else {
                    isLoading = false
                    quotations = data
                }
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    func showFilter() { showFilterSheet = true }
    func dismissFilter() { showFilterSheet = false }

    func onSearchSkillsChanged(_ value: String) { searchSkills = value }
    func onSearchNameChanged(_ value: String) { searchName = value }

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
                searchQuotations()
            } else {
                showPlaceList = false
                placeList = []
            }
        }
    }

    func clearSearchLocation() {
        searchAddress = ""
        latitude = 0.0
        longitude = 0.0
        loadData()
    }

    func applyFilter() {
        showFilterSheet = false
        searchQuotations()
    }

    func clearFilter() {
        searchSkills = ""
        searchName = ""
        searchAddress = ""
        latitude = 0.0
        longitude = 0.0
        showFilterSheet = false
        loadData()
    }

    private func searchQuotations() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            let result = await shiftRepository.getQuotationsBySearch(
                shiftId: shiftId,
                latitude: latitude,
                longitude: longitude,
                searchSkills: searchSkills,
                searchName: searchName
            )
            switch result {
            case .success(let data):
                if data.isEmpty {
                    isLoading = false
                    quotations = []
                    errorMessage = "No Quotation found."
                } else {
                    isLoading = false
                    quotations = data
                }
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    func sortBy(_ column: String) {
        let ascending = sortColumn == column ? !sortAscending : true
        quotations.sort { a, b in
            let aVal: String
            let bVal: String
            switch column {
            case "ContractorName": aVal = a.contractorName.lowercased(); bVal = b.contractorName.lowercased()
            case "ContractorEmail": aVal = a.contractorEmail.lowercased(); bVal = b.contractorEmail.lowercased()
            case "ContractorPhone": aVal = a.contractorPhone.lowercased(); bVal = b.contractorPhone.lowercased()
            case "ContractorAddress": aVal = a.contractorAddress.lowercased(); bVal = b.contractorAddress.lowercased()
            case "QuotedDate": aVal = a.quotedDate ?? ""; bVal = b.quotedDate ?? ""
            case "Notes": aVal = a.notes.lowercased(); bVal = b.notes.lowercased()
            case "QuotedAmount": aVal = String(format: "%020.2f", a.quotedAmount); bVal = String(format: "%020.2f", b.quotedAmount)
            case "Skills": aVal = a.skills.lowercased(); bVal = b.skills.lowercased()
            default: aVal = ""; bVal = ""
            }
            return ascending ? aVal < bVal : aVal > bVal
        }
        sortColumn = column
        sortAscending = ascending
    }

    func hireContractor(_ quotation: JobQuotationDto) {
        guard let currentShift = shift else { return }
        isHiring = true
        errorMessage = nil

        Task { @MainActor in
            let userId = preferencesManager.userId
            var updated = currentShift
            updated.caregiverId = quotation.caregiverId
            updated.caregiverName = quotation.contractorName
            updated.caregiverEmail = quotation.contractorEmail
            updated.caregiverPhone = quotation.contractorPhone
            updated.statusId = 2 // Accepted
            updated.modifiedBy = userId

            let result = await shiftRepository.updateShift(shiftDetail: updated)
            switch result {
            case .success:
                isHiring = false
                successMessage = "Contractor Hired Sucessfully"
                isHired = true
            case .error(let message, _):
                isHiring = false
                errorMessage = (message ?? "").isEmpty ? "There was a problem in Hiring Contractor" : message
            case .loading: break
            }
        }
    }

    func formatDate(_ dateStr: String?) -> String {
        guard let dateStr = dateStr, !dateStr.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.dateFormat = "dd/MM/yyyy hh:mm a"
        for fmt in parseFormats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: dateStr.trimmingCharacters(in: .whitespaces)) {
                return displayFormatter.string(from: date)
            }
        }
        let trimmed = dateStr.replacingOccurrences(of: #"\.\d+$"#, with: "", options: .regularExpression)
        formatter.dateFormat = parseFormats[0]
        if let date = formatter.date(from: trimmed) {
            return displayFormatter.string(from: date)
        }
        return dateStr
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }
}
