import Foundation

struct ShiftSubItemDto: Codable, Identifiable, Hashable {
    var id: Int = 0
    var shiftId: Int = 0
    var isDeleteSubItem: Bool = false
    var subitem: String = ""
    var hsRequired: Int = 0
    var status: Int = 0
    var jobCategory: Int = 1 // 1 = Primary, 2 = Secondary
    var isContractor: Bool = false
    var dateStarted: String? = nil
    var dateCompleted: String? = nil
    var createdBy: String = ""
    var createdByIp: String = ""
    var createdDate: String? = nil
    var modifiedBy: String = ""
    var modifiedByIp: String = ""
    var modifiedDate: String? = nil
    var hsRequiredColour: String = ""
    var statusColour: String = ""
    var hsRequiredText: String = ""
    var statusText: String = ""
    var dateStartedString: String = ""
    var dateCompletedString: String = ""
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
        case isDeleteSubItem
        case subitem
        case hsRequired
        case status
        case jobCategory
        case isContractor
        case dateStarted
        case dateCompleted
        case createdBy
        case createdByIp = "createdByIP"
        case createdDate
        case modifiedBy
        case modifiedByIp = "modifiedByIP"
        case modifiedDate
        case hsRequiredColour
        case statusColour
        case hsRequiredText
        case statusText
        case dateStartedString
        case dateCompletedString
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case errorMessage
        case basicAuthUid
    }

    static func == (lhs: ShiftSubItemDto, rhs: ShiftSubItemDto) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
