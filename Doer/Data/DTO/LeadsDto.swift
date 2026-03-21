import Foundation

struct LeadsDto: Codable, Identifiable {
    var id: Int = 0
    var name: String = ""
    var jobDescription: String = ""
    var contractType: Int? = nil
    var contractTypeName: String = ""
    var contractTypeColor: String = ""
    var statusId: Int = 0
    var statusName: String = ""
    var statusColor: String = ""
    var location: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var costFromQuote: Double? = nil
    var clientName: String = ""
    var clientEmail: String = ""
    var clientId: Int? = nil
    var createdBy: String = ""
    var createdByIp: String = ""
    var createdDate: String? = nil
    var modifiedBy: String = ""
    var modifiedByIp: String = ""
    var modifiedDate: String? = nil
    var ownerId: String = ""
    var ownerName: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case jobDescription
        case contractType
        case contractTypeName
        case contractTypeColor
        case statusId
        case statusName
        case statusColor
        case location
        case latitude
        case longitude
        case costFromQuote
        case clientName
        case clientEmail
        case clientId
        case createdBy
        case createdByIp = "createdByIP"
        case createdDate
        case modifiedBy
        case modifiedByIp = "modifiedByIP"
        case modifiedDate
        case ownerId
        case ownerName
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case errorMessage
        case status
        case basicAuthUid
    }
}
