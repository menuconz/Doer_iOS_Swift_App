import Foundation
import SwiftUI

struct ContractTypeOption: Identifiable {
    let id: Int
    let name: String
}

@Observable
class AddShiftViewModel {
    // State
    var projectName: String = ""
    var selectedClientIndex: Int = 0
    var clients: [ClientDto] = []
    var isAllDay: Bool = false
    var durationFromDate: Date = Date()
    var durationFromTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    var durationToDate: Date = Date()
    var durationToTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 13
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    var searchAddress: String = ""
    var address: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var placeSuggestions: [PlacePrediction] = []
    var showSuggestions: Bool = false
    var selectedContractTypeIndex: Int = 0
    var selectedReminderIndex: Int = 0
    var instructions: String = ""
    var isSubmitting: Bool = false
    var errorMessage: String? = nil
    var isSuccess: Bool = false

    let contractTypes: [ContractTypeOption] = [
        ContractTypeOption(id: 0, name: "Select Contract Type"),
        ContractTypeOption(id: 1, name: "To Be Confirmed"),
        ContractTypeOption(id: 2, name: "Full Contract"),
        ContractTypeOption(id: 3, name: "Supply Place And Finish"),
        ContractTypeOption(id: 4, name: "Place And Finish"),
        ContractTypeOption(id: 5, name: "Labour Supply"),
        ContractTypeOption(id: 6, name: "Box Place And Finish"),
        ContractTypeOption(id: 7, name: "Remedial"),
        ContractTypeOption(id: 8, name: "Supply Place Finish And Cut"),
        ContractTypeOption(id: 9, name: "Place Finish And Cut"),
        ContractTypeOption(id: 10, name: "Other Services"),
        ContractTypeOption(id: 11, name: "Meetings")
    ]

    let reminderOptions: [ReminderOption] = [
        ReminderOption(label: "None", offsetMinutes: 0),
        ReminderOption(label: "5 minutes before", offsetMinutes: 5),
        ReminderOption(label: "15 minutes before", offsetMinutes: 15),
        ReminderOption(label: "30 minutes before", offsetMinutes: 30),
        ReminderOption(label: "1 hour before", offsetMinutes: 60),
        ReminderOption(label: "2 hours before", offsetMinutes: 120),
        ReminderOption(label: "4 hours before", offsetMinutes: 240),
        ReminderOption(label: "1 day before", offsetMinutes: 1440),
        ReminderOption(label: "2 days before", offsetMinutes: 2880)
    ]

    private let shiftRepository: ShiftRepository
    private let clientRepository: ClientRepository
    private let preferencesManager: PreferencesManager
    private let googlePlacesService: GooglePlacesService
    private var searchTask: Task<Void, Never>? = nil
    private var hasLoaded = false

    init(
        date: String = "",
        hour: Int? = nil,
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        clientRepository: ClientRepository = DIContainer.shared.clientRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager,
        googlePlacesService: GooglePlacesService = DIContainer.shared.googlePlacesService
    ) {
        self.shiftRepository = shiftRepository
        self.clientRepository = clientRepository
        self.preferencesManager = preferencesManager
        self.googlePlacesService = googlePlacesService

        // Parse date
        if !date.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsedDate = formatter.date(from: date) {
                durationFromDate = parsedDate
                durationToDate = parsedDate
            }
        }

        // Parse hour
        let fromHour = hour ?? 12
        let toHour = min(fromHour + 1, 23)
        var fromComponents = Calendar.current.dateComponents([.year, .month, .day], from: durationFromDate)
        fromComponents.hour = fromHour
        fromComponents.minute = 0
        if let fromTime = Calendar.current.date(from: fromComponents) {
            durationFromTime = fromTime
        }
        var toComponents = Calendar.current.dateComponents([.year, .month, .day], from: durationToDate)
        toComponents.hour = toHour
        toComponents.minute = 0
        if let toTime = Calendar.current.date(from: toComponents) {
            durationToTime = toTime
        }
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadClients()
    }

    private func loadClients() {
        Task { @MainActor in
            switch await clientRepository.getAllClients() {
            case .success(let data):
                var selectClient = ClientDto()
                selectClient.id = 0
                selectClient.name = "Select Client"
                clients = [selectClient] + data
            case .error(let msg, _):
                print("Failed to load clients: \(msg)")
            case .loading: break
            }
        }
    }

    func onProjectNameChange(_ value: String) {
        projectName = value
    }

    func onClientChange(_ index: Int) {
        selectedClientIndex = index
    }

    func onAllDayChange(_ value: Bool) {
        isAllDay = value
    }

    func onDurationFromDateChange(_ date: Date) {
        durationFromDate = date
    }

    func onDurationFromTimeChange(_ time: Date) {
        durationFromTime = time
    }

    func onDurationToDateChange(_ date: Date) {
        durationToDate = date
    }

    func onDurationToTimeChange(_ time: Date) {
        durationToTime = time
    }

    func onSearchAddressChange(_ value: String) {
        searchAddress = value
        searchTask?.cancel()

        if value.count >= 3 {
            searchTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
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

    func onContractTypeChange(_ index: Int) {
        selectedContractTypeIndex = index
    }

    func onReminderChange(_ index: Int) {
        selectedReminderIndex = index
    }

    func onInstructionsChange(_ value: String) {
        instructions = value
    }

    func clearError() {
        errorMessage = nil
    }

    func createShift() {
        // Validation
        if address.isEmpty {
            errorMessage = "Please enter the job address"
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        let fromDateStr = dateFormatter.string(from: durationFromDate)
        let toDateStr = dateFormatter.string(from: durationToDate)

        let fromDateTime: String
        let toDateTime: String

        if isAllDay {
            fromDateTime = "\(fromDateStr)T00:00:00"
            toDateTime = "\(toDateStr)T23:59:59"
        } else {
            let fromTimeStr = timeFormatter.string(from: durationFromTime)
            let toTimeStr = timeFormatter.string(from: durationToTime)
            fromDateTime = "\(fromDateStr)T\(fromTimeStr)"
            toDateTime = "\(toDateStr)T\(toTimeStr)"
        }

        if toDateTime <= fromDateTime {
            errorMessage = "End date/time must be after start date/time"
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task { @MainActor in
            let userId = preferencesManager.userId
            let nowFormatter = DateFormatter()
            nowFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let now = nowFormatter.string(from: Date())

            let selectedClient = clients.indices.contains(selectedClientIndex) ? clients[selectedClientIndex] : nil
            let clientId: Int? = (selectedClient != nil && selectedClient!.id > 0) ? selectedClient!.id : nil
            let contractTypeId = contractTypes.indices.contains(selectedContractTypeIndex) ? contractTypes[selectedContractTypeIndex].id : nil
            let contractType: Int? = (contractTypeId != nil && contractTypeId! > 0) ? contractTypeId : nil
            let reminder = reminderOptions.indices.contains(selectedReminderIndex) ? reminderOptions[selectedReminderIndex] : nil
            let isReminderScheduled = reminder != nil && reminder!.offsetMinutes > 0

            var shift = ShiftDto()
            shift.userId = userId
            shift.projectName = projectName
            shift.durationFrom = fromDateTime
            shift.durationTo = toDateTime
            shift.address = address
            shift.latitude = latitude != 0.0 ? latitude : nil
            shift.longitude = longitude != 0.0 ? longitude : nil
            shift.instructions = instructions
            shift.statusId = 1
            shift.contractType = contractType
            shift.invoiceStatus = 1
            shift.isAllDay = isAllDay
            shift.isReminderScheduled = isReminderScheduled
            if isReminderScheduled {
                // Convert total minutes → HH:mm:ss (minutes/seconds must stay 0-59 for C# TimeSpan.Parse)
                let totalMin = reminder!.offsetMinutes
                shift.reminderOffset = String(format: "%02d:%02d:00", totalMin / 60, totalMin % 60)
            } else {
                shift.reminderOffset = nil
            }
            shift.clientId = clientId
            shift.createdBy = userId
            shift.createdDate = now
            shift.modifiedBy = userId
            shift.modifiedDate = now

            switch await shiftRepository.createShift(shiftDetail: shift) {
            case .success:
                isSubmitting = false
                isSuccess = true
            case .error(let msg, _):
                isSubmitting = false
                errorMessage = msg
            case .loading: break
            }
        }
    }
}
