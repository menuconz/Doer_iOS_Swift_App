import Foundation

// MARK: - Login Request
struct LoginRequestDto: Codable {
    var email: String
    var password: String
    var deviceToken: String = ""
    var deviceTypeId: Int = 2
    var osId: Int = 1
    var siteId: Int = 1
    var lId: Int = 1

    enum CodingKeys: String, CodingKey {
        case email = "Email"
        case password = "Password"
        case deviceToken = "DeviceToken"
        case deviceTypeId = "DeviceTypeId"
        case osId = "OSID"
        case siteId = "SiteId"
        case lId = "LId"
    }
}

// MARK: - JobQuotation
struct JobQuotationDto: Codable, Identifiable {
    var id: Int = 0
    var shiftId: Int = 0
    var caregiverId: String = ""
    var quotedAmount: Double = 0.0
    var quotedDate: String? = nil
    var status: String = ""
    var notes: String = ""
    var createdBy: String = ""
    var createdByIp: String = ""
    var createdDate: String? = nil
    var modifiedBy: String = ""
    var modifiedByIp: String = ""
    var modifiedDate: String? = nil
    var contractorName: String = ""
    var contractorEmail: String = ""
    var contractorPhone: String = ""
    var contractorAddress: String = ""
    var skills: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case shiftId
        case caregiverId
        case quotedAmount
        case quotedDate
        case status
        case notes
        case createdBy
        case createdByIp = "createdByIP"
        case createdDate
        case modifiedBy
        case modifiedByIp = "modifiedByIP"
        case modifiedDate
        case contractorName
        case contractorEmail
        case contractorPhone
        case contractorAddress
        case skills
        case lId
        case siteId
        case contactId = "contactID"
        case userId
        case errorMessage
        case basicAuthUid
    }
}

// MARK: - RestHome
struct RestHomeDto: Codable, Identifiable {
    var id: Int = 0
    var name: String = ""
    var address: String = ""
    var mobile: String = ""
    var numberOfBeds: Int = 0
    var latitude: Double? = nil
    var longitude: Double? = nil
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case address = "Address"
        case mobile = "Mobile"
        case numberOfBeds = "NumberOfBeds"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}

// MARK: - CaregiverLevel
struct CaregiverLevelDto: Codable, Identifiable {
    var id: Int = 0
    var levelName: String = ""

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case levelName = "LevelName"
    }
}

// MARK: - Notifications
struct NotificationsDto: Codable, Identifiable {
    var id: Int = 0
    var userId: String = ""
    var shiftId: Int? = nil
    var projectName: String = ""
    var shiftStatusId: String = ""
    var userDeviceToken: String = ""
    var userDeviceType: Int = 0
    var title: String = ""
    var body: String = ""
    var firebaseMessageId: String = ""
    var notificationStatus: Int = 1
    var sentAt: String = ""
    var deliveredAt: String? = nil
    var readAt: String? = nil
    var errorMessage: String = ""
    var notificationType: String = ""
    var isRead: Bool = false
    var emailMessageId: Int? = nil
    var data: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case shiftId
        case projectName
        case shiftStatusId
        case userDeviceToken
        case userDeviceType
        case title
        case body
        case firebaseMessageId
        case notificationStatus = "status"
        case sentAt
        case deliveredAt
        case readAt
        case errorMessage
        case notificationType
        case isRead
        case emailMessageId
        case data
    }
}

// MARK: - MainMenu
struct MainMenuDto: Codable {
    var isMyTeamVisible: Bool = false
    var isAgreement: Bool = false
    var isInformation: Bool = false
    var fullSizeProfileImage: String = ""
    var thumbnailProfileImage: String = ""
    var isConsent: Bool = false
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case isMyTeamVisible = "IsMyTeamVisible"
        case isAgreement = "IsAgreement"
        case isInformation = "IsInformation"
        case fullSizeProfileImage = "FullSizeProfileImage"
        case thumbnailProfileImage = "ThumbnailProfileImage"
        case isConsent = "IsConsent"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}

// MARK: - UserLocation
struct UserLocationDto: Codable {
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var timestamp: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case latitude = "Latitude"
        case longitude = "Longitude"
        case timestamp = "Timestamp"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}

// MARK: - Logs
struct LogsDto: Codable {
    var id: Int = 0
    var timestamp: String = ""
    var level: String = ""
    var template: String = ""
    var message: String = ""
    var exception: String = ""
    var properties: String = ""
    var ts: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case timestamp = "Timestamp"
        case level = "Level"
        case template = "Template"
        case message = "Message"
        case exception = "Exception"
        case properties = "Properties"
        case ts = "_ts"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}

// MARK: - Contactus
struct ContactusDto: Codable {
    var name: String = ""
    var email: String = ""
    var phoneNumber: String = ""
    var message: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case email = "Email"
        case phoneNumber = "PhoneNumber"
        case message = "Message"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}

// MARK: - RegisterUserWithoutDocument
struct RegisterUserWithoutDocumentDto: Codable {
    var caregiverLevelId: Int = 0
    var displayName: String = ""
    var email: String = ""
    var password: String = ""
    var restHomeId: Int? = nil
    var dateOfBirth: String? = nil
    var phoneNumber: String = ""
    var deviceToken: String = ""
    var deviceTypeId: Int = 2
    var address: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var perHourCharges: Double? = nil
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case caregiverLevelId = "CaregiverLevelId"
        case displayName = "DisplayName"
        case email = "Email"
        case password = "Password"
        case restHomeId = "RestHomeId"
        case dateOfBirth = "DateOfBirth"
        case phoneNumber = "PhoneNumber"
        case deviceToken = "DeviceToken"
        case deviceTypeId = "DeviceTypeId"
        case address = "Address"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case perHourCharges = "PerHourCharges"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case basicAuthUid = "BasicAuthUid"
    }
}

// MARK: - ForgotPasswordModel
struct ForgotPasswordModelDto: Codable {
    var firstName: String = ""
    var lastName: String = ""
    var emailId: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case firstName = "FirstName"
        case lastName = "LastName"
        case emailId = "EmailId"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}

// MARK: - PaymarkPayment
struct PaymarkPaymentRequestDto: Codable {
    var username: String = ""
    var password: String = ""
    var accountId: Int = 0
    var amount: Double = 0.0
    var cmd: String = ""
    var displayCustomerEmail: String = ""
    var particular: String = ""
    var reference: String = ""
    var storePaymentToken: String = ""
    var tokenReference: String = ""
    var type: String = ""
    var returnUrl: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case accountId = "account_id"
        case amount
        case cmd
        case displayCustomerEmail = "display_customer_email"
        case particular
        case reference
        case storePaymentToken = "store_payment_token"
        case tokenReference = "token_reference"
        case type
        case returnUrl = "return_url"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case basicAuthUid = "BasicAuthUid"
    }
}

struct PaymarkPaymentResponseDto: Codable {
    var success: String = ""
    var failure: String = ""
    var code: Int = 0
    var message: String = ""
}

// MARK: - GooglePlace
struct GooglePlaceAutoCompletePrediction: Codable {
    var description: String = ""
    var id: String = ""
    var placeId: String = ""
    var reference: String = ""
    var structuredFormatting: StructuredFormatting? = nil

    enum CodingKeys: String, CodingKey {
        case description
        case id
        case placeId = "place_id"
        case reference
        case structuredFormatting = "structured_formatting"
    }
}

struct StructuredFormatting: Codable {
    var mainText: String = ""
    var secondaryText: String = ""

    enum CodingKeys: String, CodingKey {
        case mainText = "main_text"
        case secondaryText = "secondary_text"
    }
}

struct GooglePlaceAutoCompleteResult: Codable {
    var status: String = ""
    var autoCompletePlaces: [GooglePlaceAutoCompletePrediction] = []

    enum CodingKeys: String, CodingKey {
        case status
        case autoCompletePlaces = "predictions"
    }
}
