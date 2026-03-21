import Foundation

struct FileModelDto: Codable {
    var id: Int = 0
    var name: String = ""
    var size: Int64 = 0
    var type: String = ""
    var fileUrl: String = ""
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
        case size
        case type
        case fileUrl = "fileURL"
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case errorMessage
        case status
        case basicAuthUid
    }
}

struct FileUploadModelDto: Codable {
    var shiftId: String = ""
    var fileName: String = ""
    var fileUrl: String = ""
    var createdBy: String = ""
    var createdByName: String = ""
    var createdDate: String = ""
    var fileSize: String = ""
    var fileExtension: String = ""
    var isImage: Bool = false
    var thumbnailUrl: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case shiftId
        case fileName
        case fileUrl
        case createdBy
        case createdByName
        case createdDate
        case fileSize
        case fileExtension
        case isImage
        case thumbnailUrl
        case lId
        case siteId
        case contactId
        case userId
        case errorMessage
        case status
        case basicAuthUid
    }
}

struct FileUploadResponseDto: Codable {
    var success: Bool = false
    var message: String = ""
    var uploadedFiles: [FileUploadModelDto] = []
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case success = "Success"
        case message = "Message"
        case uploadedFiles = "UploadedFiles"
        case lId = "LId"
        case siteId = "SiteId"
        case contactId = "ContactID"
        case userId = "UserID"
        case errorMessage = "ErrorMessage"
        case status = "Status"
        case basicAuthUid = "BasicAuthUid"
    }
}
