import Foundation

class DIContainer {
    static let shared = DIContainer()

    // MARK: - Local Storage
    let preferencesManager = PreferencesManager.shared
    let secureStorageManager = SecureStorageManager.shared

    // MARK: - API Services
    lazy var accountApi = AccountApi()
    lazy var shiftApi = ShiftApi()
    lazy var leadApi = LeadApi()
    lazy var clientApi = ClientApi()
    lazy var emailMessageApi = EmailMessageApi()
    lazy var chatMessageApi = ChatMessageApi()
    lazy var restHomeApi = RestHomeApi()
    lazy var caregiverLevelApi = CaregiverLevelApi()
    lazy var locationTrackingApi = LocationTrackingApi()
    lazy var logsApi = LogsApi()

    // MARK: - Repositories
    lazy var accountRepository = AccountRepository(accountApi: accountApi, prefs: preferencesManager)
    lazy var shiftRepository = ShiftRepository(shiftApi: shiftApi, prefs: preferencesManager)
    lazy var leadRepository = LeadRepository(leadApi: leadApi)
    lazy var clientRepository = ClientRepository(clientApi: clientApi)
    lazy var emailMessageRepository = EmailMessageRepository(emailApi: emailMessageApi, prefs: preferencesManager)
    lazy var chatMessageRepository = ChatMessageRepository(chatApi: chatMessageApi)
    lazy var restHomeRepository = RestHomeRepository(restHomeApi: restHomeApi)
    lazy var caregiverLevelRepository = CaregiverLevelRepository(caregiverLevelApi: caregiverLevelApi)
    lazy var locationTrackingRepository = LocationTrackingRepository(locationApi: locationTrackingApi, prefs: preferencesManager)
    lazy var logsRepository = LogsRepository(logsApi: logsApi, prefs: preferencesManager)

    // MARK: - Services
    lazy var googlePlacesService = GooglePlacesService.shared

    private init() {}
}
