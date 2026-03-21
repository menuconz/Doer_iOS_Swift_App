import Foundation
import Alamofire

class EmailMessageApi {
    private let network = NetworkManager.shared

    func getEmailThreadById(emailMessageId: Int) async throws -> EmailThreadDto {
        return try await network.get("EmailMessages/getEmailThread", parameters: ["emailMessageId": emailMessageId])
    }

    func markEmailAsRead(emailMessageId: Int) async throws -> EmailThreadDto {
        return try await network.get("EmailMessages/mark-read", parameters: ["emailMessageId": emailMessageId])
    }

    func getAllEmailMessageByShiftId(shiftId: Int) async throws -> [EmailThreadDto] {
        return try await network.get("EmailMessages/getShiftEmailsWithThreads/\(shiftId)")
    }

    func getSubItemAllEmailMessage(shiftId: Int, subItemId: Int) async throws -> [EmailThreadDto] {
        return try await network.get("EmailMessages/getSubItemEmailsWithThreads/\(shiftId)/\(subItemId)")
    }

    func sendEmailReply(request: SendEmailReplyRequestDto) async throws -> EmailMessageDto {
        return try await network.post("EmailMessages/reply", body: request)
    }

    func sendSubItemEmailReply(request: SendEmailReplyRequestDto) async throws -> EmailMessageDto {
        return try await network.post("EmailMessages/reply-subitem", body: request)
    }

    func sendNewEmail(request: NewEmailRequestDto) async throws -> EmailMessageDto {
        return try await network.post("EmailMessages/send-new", body: request)
    }

    func sendNewEmailWithAttachments(
        fields: [String: String],
        attachments: [(data: Data, name: String, fileName: String, mimeType: String)]
    ) async throws -> EmailMessageDto {
        return try await network.upload("EmailMessages/send-new-emailwithattachment", fields: fields, files: attachments)
    }

    func sendNewSubItemEmailWithAttachments(
        fields: [String: String],
        attachments: [(data: Data, name: String, fileName: String, mimeType: String)]
    ) async throws -> EmailMessageDto {
        return try await network.upload("EmailMessages/send-new-subitem-emailwithattachment", fields: fields, files: attachments)
    }
}
