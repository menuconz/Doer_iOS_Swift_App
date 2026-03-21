import Foundation

struct ChatMessageModelDto: Codable, Identifiable {
    var id: Int = 0
    var shiftId: Int = 0
    var sentById: String = ""
    var senderName: String = ""
    var sentToId: String = ""
    var message: String = ""
    var sentAtUtc: String = ""
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
        case shiftId = "ShiftId"
        case sentById = "SentById"
        case senderName = "SenderName"
        case sentToId = "SentToId"
        case message = "Message"
        case sentAtUtc = "SentAtUtc"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}
