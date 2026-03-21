import Foundation

class EmailMessageRepository {
    private let emailApi: EmailMessageApi
    private let prefs: PreferencesManager

    init(emailApi: EmailMessageApi = EmailMessageApi(), prefs: PreferencesManager = .shared) {
        self.emailApi = emailApi
        self.prefs = prefs
    }

    func getEmailThreadById(emailMessageId: Int) async -> ApiResult<EmailThreadDto> {
        await safeApiCall { try await self.emailApi.getEmailThreadById(emailMessageId: emailMessageId) }
    }

    func markEmailAsRead(emailMessageId: Int) async -> ApiResult<EmailThreadDto> {
        await safeApiCall { try await self.emailApi.markEmailAsRead(emailMessageId: emailMessageId) }
    }

    func getAllEmailMessageByShiftId(shiftId: Int) async -> ApiResult<[EmailThreadDto]> {
        await safeApiCall { try await self.emailApi.getAllEmailMessageByShiftId(shiftId: shiftId) }
    }

    func getSubItemAllEmailMessage(shiftId: Int, subItemId: Int) async -> ApiResult<[EmailThreadDto]> {
        await safeApiCall { try await self.emailApi.getSubItemAllEmailMessage(shiftId: shiftId, subItemId: subItemId) }
    }

    func sendEmailReply(request: SendEmailReplyRequestDto) async -> ApiResult<EmailMessageDto> {
        await safeApiCall { try await self.emailApi.sendEmailReply(request: request) }
    }

    func sendSubItemEmailReply(request: SendEmailReplyRequestDto) async -> ApiResult<EmailMessageDto> {
        await safeApiCall { try await self.emailApi.sendSubItemEmailReply(request: request) }
    }

    func sendNewEmail(request: NewEmailRequestDto) async -> ApiResult<EmailMessageDto> {
        await safeApiCall { try await self.emailApi.sendNewEmail(request: request) }
    }

    func sendNewEmailWithAttachments(
        jobId: Int, toEmail: String, subject: String, body: String, ccEmail: String,
        attachments: [(data: Data, fileName: String)]
    ) async -> ApiResult<EmailMessageDto> {
        return await safeApiCall {
            let requestJson: [String: Any] = [
                "UserID": self.prefs.userId,
                "JobId": jobId,
                "ToEmail": toEmail,
                "Subject": subject,
                "Body": body,
                "CcEmail": ccEmail
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: requestJson)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            let fields: [String: String] = ["request": jsonString]
            let files = attachments.map { file in
                (data: file.data, name: "attachments", fileName: file.fileName, mimeType: NetworkManager.getMimeType(file.fileName))
            }
            return try await self.emailApi.sendNewEmailWithAttachments(fields: fields, attachments: files)
        }
    }

    func sendNewSubItemEmailWithAttachments(
        jobId: Int, subItemId: Int, toEmail: String, subject: String, body: String, ccEmail: String,
        attachments: [(data: Data, fileName: String)]
    ) async -> ApiResult<EmailMessageDto> {
        return await safeApiCall {
            let requestJson: [String: Any] = [
                "UserID": self.prefs.userId,
                "JobId": jobId,
                "SubItemId": subItemId,
                "ToEmail": toEmail,
                "Subject": subject,
                "Body": body,
                "CcEmail": ccEmail
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: requestJson)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            let fields: [String: String] = ["request": jsonString]
            let files = attachments.map { file in
                (data: file.data, name: "attachments", fileName: file.fileName, mimeType: NetworkManager.getMimeType(file.fileName))
            }
            return try await self.emailApi.sendNewSubItemEmailWithAttachments(fields: fields, attachments: files)
        }
    }
}
