import Foundation
import SwiftUI

let contractTypeList = [
    "ToBeConfirmed",
    "FullContract",
    "SupplyPlaceAndFinish",
    "PlaceAndFinish",
    "LabourSupply",
    "BoxPlaceAndFinish",
    "Remedial",
    "SupplyPlaceFinishAndCut",
    "PlaceFinishAndCut",
    "OtherServices",
    "Meetings"
]

@Observable
class AddNewLeadViewModel {
    var projectName: String = ""
    var jobDescription: String = ""
    var costFromQuote: String = ""
    // Client
    var clients: [ClientDto] = []
    var selectedClient: ClientDto? = nil
    var clientName: String = ""
    var clientEmail: String = ""
    var clientId: Int? = nil
    // Owner
    var owners: [UserDto] = []
    var selectedOwner: UserDto? = nil
    // Contract Type
    var selectedContractType: Int = 0
    // Location with Google Places
    var searchAddress: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var placeList: [PlacePrediction] = []
    var showPlaceList: Bool = false
    // State
    var isLoading: Bool = true
    var isSubmitting: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var isSuccess: Bool = false

    private let leadRepository: LeadRepository
    private let clientRepository: ClientRepository
    private let accountRepository: AccountRepository
    private let preferencesManager: PreferencesManager
    private let googlePlacesService: GooglePlacesService

    private var searchTask: Task<Void, Never>? = nil
    private var hasLoaded = false

    init(
        leadRepository: LeadRepository = DIContainer.shared.leadRepository,
        clientRepository: ClientRepository = DIContainer.shared.clientRepository,
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService
    ) {
        self.leadRepository = leadRepository
        self.clientRepository = clientRepository
        self.accountRepository = accountRepository
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

            // Load clients
            let clientsResult = await clientRepository.getAllClients()
            if case .success(let data) = clientsResult {
                clients = data
            }

            // Load owners (add "Select Owner" default)
            let ownersResult = await accountRepository.getAllManagerAndAdminUsers()
            switch ownersResult {
            case .success(let data):
                let selectOwner = UserDto(displayName: "Select Owner", id: "")
                owners = [selectOwner] + data
                selectedOwner = selectOwner
                isLoading = false
            case .error:
                isLoading = false
            case .loading:
                break
            }
        }
    }

    func onProjectNameChange(_ value: String) {
        projectName = value
    }

    func onJobDescriptionChange(_ value: String) {
        jobDescription = value
    }

    func onCostChange(_ value: String) {
        costFromQuote = value
    }

    func onClientSelected(_ client: ClientDto) {
        selectedClient = client
        clientId = client.id
        clientName = client.name
        clientEmail = client.email
    }

    func onOwnerSelected(_ owner: UserDto) {
        selectedOwner = owner
    }

    func onContractTypeSelected(_ index: Int) {
        selectedContractType = index + 1 // 1-based
    }

    // Google Places - matching MAUI OnSearchAddressChanged + GetSearchList
    func onSearchAddressChange(_ value: String) {
        searchAddress = value
        searchTask?.cancel()
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            placeList = []
            showPlaceList = false
        } else {
            searchTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
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
                showPlaceList = false
                placeList = []
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = nil
    }

    func addLead() {
        // Validate required fields
        let hasErrors = projectName.trimmingCharacters(in: .whitespaces).isEmpty
            || jobDescription.trimmingCharacters(in: .whitespaces).isEmpty
            || searchAddress.trimmingCharacters(in: .whitespaces).isEmpty

        if hasErrors {
            errorMessage = "Please Enter Required Fields."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let userId = preferencesManager.userId
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                let now = dateFormatter.string(from: Date())

                var lead = LeadsDto()
                lead.userId = userId
                lead.name = projectName
                lead.jobDescription = jobDescription
                lead.clientId = clientId
                lead.clientName = clientName
                lead.clientEmail = clientEmail
                lead.costFromQuote = Double(costFromQuote)
                lead.location = searchAddress
                lead.latitude = latitude
                lead.longitude = longitude
                lead.createdDate = now
                lead.createdBy = userId
                lead.modifiedDate = now
                lead.modifiedBy = userId
                lead.statusId = 1 // NewLead
                lead.contractType = selectedContractType > 0 ? selectedContractType : nil
                lead.ownerId = selectedOwner?.id ?? ""
                lead.basicAuthUid = preferencesManager.basicAuthUid

                let result = await leadRepository.createNewLead(leadDetail: lead)
                switch result {
                case .success:
                    isSubmitting = false
                    isSuccess = true
                case .error:
                    isSubmitting = false
                    errorMessage = "Error in creating New Lead."
                case .loading:
                    break
                }
            }
        }
    }
}
