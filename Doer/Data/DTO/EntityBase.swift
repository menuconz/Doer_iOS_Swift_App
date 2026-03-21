import Foundation

struct EntityBase: Codable {
    var lId: Int = 0
    var siteId: Int = 1
    var gamesId: Int = 0
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case lId = "LId"
        case siteId = "SiteId"
        case gamesId = "GamesId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}
