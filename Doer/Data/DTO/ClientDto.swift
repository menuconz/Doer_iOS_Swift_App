import Foundation

struct ClientDto: Codable, Identifiable {
    var id: Int = 0
    var name: String = ""
    var email: String = ""
    var createdBy: String = ""
    var createdByIp: String = ""
    var createdDate: String? = nil
    var modifiedBy: String = ""
    var modifiedByIp: String = ""
    var modifiedDate: String? = nil
    var jobs: [ClientJobDto] = []
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
        case email
        case createdBy
        case createdByIp = "createdByIP"
        case createdDate
        case modifiedBy
        case modifiedByIp = "modifiedByIP"
        case modifiedDate
        case jobs
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case errorMessage
        case status
        case basicAuthUid
    }
}

struct ClientJobDto: Codable, Identifiable {
    var id: Int = 0
    var projectName: String = ""
    var isAssigned: Bool = false
    var originalIsAssigned: Bool = false
}
