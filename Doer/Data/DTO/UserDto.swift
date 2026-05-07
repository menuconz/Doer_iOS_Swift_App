import Foundation

struct UserDto: Codable, Identifiable {
    var displayName: String = ""
    var token: String = ""
    var role: String = ""
    var id: String = ""
    var caregiverLevelId: Int = 0
    var caregiverLevelName: String = ""
    var restHomeId: Int? = nil
    var username: String = ""
    var phoneNumber: String = ""
    var dateOfBirth: String? = nil
    var age: Int? = nil
    var fullName: String = ""
    var password: String = ""
    var email: String = ""
    var phone: String = ""
    var loginStatusMessage: String = ""
    var isMyTeamVisible: Bool = false
    var fullSizeProfileImage: String = ""
    var thumbnailProfileImage: String = ""
    var pinAlreadyGenerated: Bool = false
    var discipline: String = ""
    var logoUrl: String = ""
    var gameUrl: String = ""
    var socialType: Int = 0
    var isConsent: Bool = false
    var isAgreement: Bool = false
    var isInformation: Bool = false
    var osId: Int = 0
    var deviceToken: String = ""
    var resourceId: Int = 0
    var adminVerified: Bool = false
    var isEmployee: Bool = false
    var deviceTypeId: Int = 0
    var address: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var locationTimestamp: String? = nil
    var perHourCharges: Double? = nil
    var documents: [FileModelDto]? = nil
    var addDocument: [FileModelDto]? = nil
    var workExperience: String = ""
    var skills: String = ""
    var dateOfBirthString: String = ""
    var isInFiloKretoTeam: Bool = false
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case displayName
        case token
        case role
        case id
        case caregiverLevelId
        case caregiverLevelName
        case restHomeId
        case username
        case phoneNumber
        case dateOfBirth = "dateofBirth"
        case age
        case fullName
        case password
        case email
        case phone
        case loginStatusMessage
        case isMyTeamVisible
        case fullSizeProfileImage
        case thumbnailProfileImage
        case pinAlreadyGenerated
        case discipline
        case logoUrl = "logoURL"
        case gameUrl = "gameURL"
        case socialType
        case isConsent
        case isAgreement
        case isInformation
        case osId = "osid"
        case deviceToken
        case resourceId = "resourceID"
        case adminVerified
        case isEmployee
        case deviceTypeId
        case address
        case latitude
        case longitude
        case locationTimestamp
        case perHourCharges
        case documents
        case addDocument
        case workExperience
        case skills
        case dateOfBirthString
        case isInFiloKretoTeam
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case errorMessage
        case status
        case basicAuthUid
    }

}
