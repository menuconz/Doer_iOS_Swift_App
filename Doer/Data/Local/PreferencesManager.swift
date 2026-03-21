import Foundation

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    private struct Keys {
        static let fullName = "full_name"
        static let phone = "phone"
        static let email = "email"
        static let discipline = "discipline"
        static let userId = "user_id"
        static let contactId = "contact_id"
        static let basicAuthUid = "basic_auth_uid"
        static let role = "role"
        static let isManager = "is_manager"
        static let isCaregiver = "is_caregiver"
        static let isCustomer = "is_customer"
        static let isAdmin = "is_admin"
        static let isContractor = "is_contractor"
    }

    // MARK: - Properties
    @Published var fullName: String {
        didSet { defaults.set(fullName, forKey: Keys.fullName) }
    }
    @Published var phone: String {
        didSet { defaults.set(phone, forKey: Keys.phone) }
    }
    @Published var email: String {
        didSet { defaults.set(email, forKey: Keys.email) }
    }
    @Published var discipline: String {
        didSet { defaults.set(discipline, forKey: Keys.discipline) }
    }
    @Published var userId: String {
        didSet { defaults.set(userId, forKey: Keys.userId) }
    }
    @Published var contactId: Int {
        didSet { defaults.set(contactId, forKey: Keys.contactId) }
    }
    @Published var basicAuthUid: String {
        didSet { defaults.set(basicAuthUid, forKey: Keys.basicAuthUid) }
    }
    @Published var role: String {
        didSet { defaults.set(role, forKey: Keys.role) }
    }
    @Published var isManager: Bool {
        didSet { defaults.set(isManager, forKey: Keys.isManager) }
    }
    @Published var isCaregiver: Bool {
        didSet { defaults.set(isCaregiver, forKey: Keys.isCaregiver) }
    }
    @Published var isCustomer: Bool {
        didSet { defaults.set(isCustomer, forKey: Keys.isCustomer) }
    }
    @Published var isAdmin: Bool {
        didSet { defaults.set(isAdmin, forKey: Keys.isAdmin) }
    }
    @Published var isContractor: Bool {
        didSet { defaults.set(isContractor, forKey: Keys.isContractor) }
    }

    private init() {
        self.fullName = defaults.string(forKey: Keys.fullName) ?? ""
        self.phone = defaults.string(forKey: Keys.phone) ?? ""
        self.email = defaults.string(forKey: Keys.email) ?? ""
        self.discipline = defaults.string(forKey: Keys.discipline) ?? ""
        self.userId = defaults.string(forKey: Keys.userId) ?? ""
        self.contactId = defaults.integer(forKey: Keys.contactId)
        self.basicAuthUid = defaults.string(forKey: Keys.basicAuthUid) ?? ""
        self.role = defaults.string(forKey: Keys.role) ?? ""
        self.isManager = defaults.bool(forKey: Keys.isManager)
        self.isCaregiver = defaults.bool(forKey: Keys.isCaregiver)
        self.isCustomer = defaults.bool(forKey: Keys.isCustomer)
        self.isAdmin = defaults.bool(forKey: Keys.isAdmin)
        self.isContractor = defaults.bool(forKey: Keys.isContractor)
    }

    // MARK: - Save User Session
    func saveUserSession(
        fullName: String,
        phone: String,
        email: String,
        userId: String,
        contactId: Int,
        basicAuthUid: String,
        role: String,
        isManager: Bool,
        isCaregiver: Bool,
        isCustomer: Bool,
        isAdmin: Bool,
        isContractor: Bool,
        discipline: String = ""
    ) {
        self.fullName = fullName
        self.phone = phone
        self.email = email
        self.userId = userId
        self.contactId = contactId
        self.basicAuthUid = basicAuthUid
        self.role = role
        self.isManager = isManager
        self.isCaregiver = isCaregiver
        self.isCustomer = isCustomer
        self.isAdmin = isAdmin
        self.isContractor = isContractor
        self.discipline = discipline
    }

    // MARK: - Clear Session
    func clearSession() {
        fullName = ""
        phone = ""
        email = ""
        discipline = ""
        userId = ""
        contactId = 0
        basicAuthUid = ""
        role = ""
        isManager = false
        isCaregiver = false
        isCustomer = false
        isAdmin = false
        isContractor = false
    }
}
