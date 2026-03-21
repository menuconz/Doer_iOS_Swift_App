import Foundation

struct EmailMessageDto: Codable, Identifiable {
    var id: Int = 0
    var jobId: Int = 0
    var subItemId: Int? = nil
    var messageId: String = ""
    var threadId: String? = nil
    var direction: String = ""
    var fromEmail: String = ""
    var toEmail: String = ""
    var ccEmail: String? = nil
    var subject: String = ""
    var body: String = ""
    var plainTextBody: String? = nil
    var status: String = ""
    var sentAt: String = ""
    var deliveredAt: String? = nil
    var readAt: String? = nil
    var isRead: Bool = false
    var isImportant: Bool = false
    var parentEmailId: Int? = nil
    var hasReplies: Bool = false
    var replyCount: Int = 0
    var attachmentInfo: String? = nil
    var attachments: [EmailAttachmentDto] = []
    var replyLevel: Int = 0
    var replies: [EmailMessageDto] = []
}

struct EmailAttachmentDto: Codable, Identifiable {
    var id: Int = 0
    var fileName: String = ""
    var fileUrl: String = ""
    var contentType: String? = nil
}

struct EmailThreadDto: Codable {
    var rootEmail: EmailMessageDto? = nil
    var replies: [EmailMessageDto] = []
    var totalMessages: Int = 0
    var unreadCount: Int = 0
    var threadId: String? = nil
    var jobId: Int = 0
    var lastActivity: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case rootEmail
        case replies
        case totalMessages
        case unreadCount
        case threadId
        case jobId
        case lastActivity
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case errorMessage
        case status
        case basicAuthUid
    }
}

struct NewEmailRequestDto: Codable {
    var jobId: Int = 0
    var toEmail: String = ""
    var subject: String = ""
    var body: String = ""
    var ccEmail: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case jobId
        case toEmail
        case subject
        case body
        case ccEmail
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case basicAuthUid
    }
}

struct NewSubItemEmailRequestDto: Codable {
    var jobId: Int = 0
    var subItemId: Int = 0
    var toEmail: String = ""
    var subject: String = ""
    var body: String = ""
    var ccEmail: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case jobId
        case subItemId
        case toEmail
        case subject
        case body
        case ccEmail
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case basicAuthUid
    }
}

struct SendEmailReplyRequestDto: Codable {
    var parentEmailId: Int = 0
    var threadId: String = ""
    var jobId: Int = 0
    var subItemId: Int? = nil
    var toEmail: String = ""
    var subject: String = ""
    var body: String = ""
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String = ""
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case parentEmailId
        case threadId
        case jobId
        case subItemId
        case toEmail
        case subject
        case body
        case lId
        case siteId
        case contactId = "contactID"
        case userId = "userID"
        case basicAuthUid
    }
}
