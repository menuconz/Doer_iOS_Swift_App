import Foundation
import SwiftUI

@Observable
class SubItemMessagesViewModel {
    var isLoading: Bool = true
    var isRefreshing: Bool = false
    var threads: [EmailThreadDto] = []
    var replyTexts: [Int: String] = [:]
    var replyMentionStates: [Int: ReplyMentionState] = [:]
    var newMessageText: String = ""
    var isSending: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var contractors: [UserDto] = []
    var mentionSuggestions: [MentionSuggestion] = []
    var showMentionSuggestions: Bool = false
    var jobId: Int = 0
    var selectedFiles: [SelectedFileItem] = []

    private let shiftId: Int
    private let subItemId: Int
    private let emailMessageRepository: EmailMessageRepository
    private let accountRepository: AccountRepository
    private let shiftRepository: ShiftRepository
    private let preferencesManager: PreferencesManager
    private var hasLoaded = false

    private let specialMentions = [
        MentionSuggestion(displayName: "Everyone", email: "everyone"),
        MentionSuggestion(displayName: "Scheduling Team", email: "scheduling"),
        MentionSuggestion(displayName: "FiloKreto Team", email: "filokreto")
    ]

    init(
        shiftId: Int,
        subItemId: Int,
        emailMessageRepository: EmailMessageRepository = DIContainer.shared.emailMessageRepository,
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository,
        preferencesManager: PreferencesManager = PreferencesManager.shared
    ) {
        self.shiftId = shiftId
        self.subItemId = subItemId
        self.emailMessageRepository = emailMessageRepository
        self.accountRepository = accountRepository
        self.shiftRepository = shiftRepository
        self.preferencesManager = preferencesManager
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadThreads()
        loadContractors()
    }

    func loadThreads() {
        Task { @MainActor in
            let result = await emailMessageRepository.getSubItemAllEmailMessage(shiftId: shiftId, subItemId: subItemId)
            switch result {
            case .success(let data):
                jobId = data.first?.jobId ?? 0
                threads = data
                isLoading = false
                isRefreshing = false
            case .error(let message, _):
                errorMessage = message
                isLoading = false
                isRefreshing = false
            case .loading: break
            }
        }
    }

    private func loadContractors() {
        Task { @MainActor in
            let result = await accountRepository.getAllContractors()
            if case .success(let data) = result { contractors = data }
        }
    }

    func refresh() {
        isRefreshing = true
        loadThreads()
    }

    func onReplyTextChanged(_ threadRootEmailId: Int, _ text: String) {
        replyTexts[threadRootEmailId] = text
        var state = replyMentionStates[threadRootEmailId] ?? ReplyMentionState()
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            state.showSuggestions = false
            state.mentionedContractorEmail = ""
            replyMentionStates[threadRootEmailId] = state
            return
        }
        let mentionedEmail = findMentionedContractorEmail(text)
        if let lastAtIndex = text.range(of: "@", options: .backwards)?.lowerBound {
            let atIdx = text.distance(from: text.startIndex, to: lastAtIndex)
            let isStart = atIdx == 0 || text[text.index(before: lastAtIndex)].isWhitespace
            if isStart {
                let afterAt = String(text[text.index(after: lastAtIndex)...])
                let spaceIdx = afterAt.firstIndex(of: " ")
                let typingText = spaceIdx != nil ? String(afterAt[..<spaceIdx!]) : afterAt
                let query = typingText.lowercased()
                if !mentionedEmail.isEmpty {
                    state.showSuggestions = false
                    state.mentionedContractorEmail = mentionedEmail
                } else {
                    let filtered = contractors.filter { query.isEmpty || $0.displayName.lowercased().contains(query) || $0.email.lowercased().contains(query) }
                        .prefix(5)
                        .map { MentionSuggestion(displayName: $0.displayName, email: $0.email) }
                    state.suggestions = Array(filtered)
                    state.showSuggestions = !filtered.isEmpty
                    state.mentionedContractorEmail = mentionedEmail
                }
            } else {
                state.showSuggestions = false
                state.mentionedContractorEmail = mentionedEmail
            }
        } else {
            state.showSuggestions = false
            state.mentionedContractorEmail = mentionedEmail
        }
        replyMentionStates[threadRootEmailId] = state
    }

    func onReplyMentionSelected(_ threadRootEmailId: Int, _ mention: MentionSuggestion) {
        guard let text = replyTexts[threadRootEmailId],
              let lastAt = text.range(of: "@", options: .backwards) else { return }
        let newText = String(text[..<lastAt.lowerBound]) + "@\(mention.displayName) "
        replyTexts[threadRootEmailId] = newText
        replyMentionStates[threadRootEmailId] = ReplyMentionState(suggestions: [], showSuggestions: false, mentionedContractorEmail: mention.email)
    }

    private func findMentionedContractorEmail(_ text: String) -> String {
        let textLower = text.lowercased()
        for contractor in contractors {
            let mention = "@\(contractor.displayName)".lowercased()
            if textLower.contains(mention) { return contractor.email }
        }
        return ""
    }

    func onNewMessageTextChanged(_ text: String) {
        newMessageText = text
        if let lastAt = text.range(of: "@", options: .backwards) {
            let afterAt = String(text[text.index(after: lastAt.lowerBound)...])
            if !afterAt.contains(" ") && !afterAt.contains("\n") {
                let query = afterAt.lowercased()
                let contractorSuggestions = contractors.filter { $0.displayName.lowercased().contains(query) || $0.email.lowercased().contains(query) }
                    .prefix(5).map { MentionSuggestion(displayName: $0.displayName, email: $0.email) }
                let special = specialMentions.filter { $0.displayName.lowercased().contains(query) }
                mentionSuggestions = special + contractorSuggestions
                showMentionSuggestions = !mentionSuggestions.isEmpty
            } else {
                showMentionSuggestions = false
            }
        } else {
            showMentionSuggestions = false
        }
    }

    func onMentionSelected(_ mention: MentionSuggestion) {
        if let lastAt = newMessageText.range(of: "@", options: .backwards) {
            newMessageText = String(newMessageText[..<lastAt.lowerBound]) + "@\(mention.displayName) "
            showMentionSuggestions = false
            mentionSuggestions = []
        }
    }

    func sendReply(_ threadRootEmailId: Int) {
        guard let thread = threads.first(where: { $0.rootEmail?.id == threadRootEmailId }),
              let rootEmail = thread.rootEmail,
              let replyText = replyTexts[threadRootEmailId]?.trimmingCharacters(in: .whitespaces),
              !replyText.isEmpty else { return }

        Task { @MainActor in
            isSending = true
            let userId = preferencesManager.userId
            let basicAuthUid = preferencesManager.basicAuthUid
            let contactId = preferencesManager.contactId
            let isManager = preferencesManager.isManager
            let isCaregiver = preferencesManager.isCaregiver

            var replyToEmail = rootEmail.fromEmail
            let mentionedEmails = extractMentionedEmails(replyText)
            if !mentionedEmails.isEmpty {
                replyToEmail = mentionedEmails[0]
            } else {
                let shiftResult = await shiftRepository.getShiftById(id: shiftId)
                if case .success(let shift) = shiftResult {
                    if isManager && !shift.caregiverId.isEmpty {
                        if case .success(let contractor) = await accountRepository.getUser(id: shift.caregiverId) {
                            replyToEmail = contractor.email
                        }
                    } else if isCaregiver, let uid = shift.userId, !uid.isEmpty {
                        if case .success(let manager) = await accountRepository.getUser(id: uid) {
                            replyToEmail = manager.email
                        }
                    }
                }
            }

            let subject = rootEmail.subject.hasPrefix("Re: ") ? rootEmail.subject : "Re: \(rootEmail.subject)"

            let request = SendEmailReplyRequestDto(
                parentEmailId: rootEmail.id,
                threadId: thread.threadId ?? "",
                jobId: thread.jobId,
                subItemId: subItemId,
                toEmail: replyToEmail,
                subject: subject,
                body: replyText,
                lId: 1,
                siteId: 1,
                contactId: contactId,
                userId: userId,
                basicAuthUid: basicAuthUid
            )

            let result = await emailMessageRepository.sendSubItemEmailReply(request: request)
            switch result {
            case .success:
                replyTexts.removeValue(forKey: threadRootEmailId)
                isSending = false
                successMessage = "Reply sent"
                loadThreads()
            case .error(let message, _):
                isSending = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    func sendNewMessage() {
        let text = newMessageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        Task { @MainActor in
            isSending = true
            let userId = preferencesManager.userId
            let basicAuthUid = preferencesManager.basicAuthUid
            let contactId = preferencesManager.contactId
            let isManager = preferencesManager.isManager
            let isCaregiver = preferencesManager.isCaregiver
            let role = preferencesManager.role

            let mentionedEmails = extractMentionedEmails(text)
            var recipients: [String] = []

            let shiftResult = await shiftRepository.getShiftById(id: shiftId)
            var shiftDetails: ShiftDto? = nil
            if case .success(let shift) = shiftResult { shiftDetails = shift }

            if !mentionedEmails.isEmpty {
                recipients.append(contentsOf: mentionedEmails)
            } else {
                if isManager, let shift = shiftDetails, !shift.caregiverId.isEmpty {
                    if case .success(let contractor) = await accountRepository.getUser(id: shift.caregiverId) {
                        recipients.append(contractor.email)
                    } else {
                        isSending = false
                        errorMessage = "Please mention a contractor because there is currently no contractor assigned to this job."
                        return
                    }
                } else if isCaregiver, let shift = shiftDetails, let uid = shift.userId, !uid.isEmpty {
                    if case .success(let manager) = await accountRepository.getUser(id: uid) {
                        recipients.append(manager.email)
                    }
                } else {
                    isSending = false
                    errorMessage = "Please mention a contractor because there is currently no contractor assigned to this job."
                    return
                }
            }

            guard !recipients.isEmpty else {
                isSending = false
                errorMessage = "No recipients found for this message."
                return
            }

            let projectName = shiftDetails?.projectName ?? ""
            let subject = "[Job #\(shiftId) \(projectName)] New Email Update from - \(role)"
            let jobIdToUse = jobId > 0 ? jobId : shiftId
            let toEmail = recipients.joined(separator: ",")

            let result: ApiResult<EmailMessageDto>

            if !selectedFiles.isEmpty {
                var attachments: [(data: Data, fileName: String)] = []
                for file in selectedFiles {
                    if let data = try? Data(contentsOf: file.url) {
                        attachments.append((data: data, fileName: file.fileName))
                    }
                }
                result = await emailMessageRepository.sendNewSubItemEmailWithAttachments(
                    jobId: jobIdToUse,
                    subItemId: subItemId,
                    toEmail: toEmail,
                    subject: subject,
                    body: text,
                    ccEmail: "",
                    attachments: attachments
                )
            } else {
                let request = NewEmailRequestDto(
                    jobId: jobIdToUse,
                    toEmail: toEmail,
                    subject: subject,
                    body: text,
                    ccEmail: "",
                    lId: 1,
                    siteId: 1,
                    contactId: contactId,
                    userId: userId,
                    basicAuthUid: basicAuthUid
                )
                result = await emailMessageRepository.sendNewEmail(request: request)
            }

            switch result {
            case .success:
                isSending = false
                newMessageText = ""
                selectedFiles = []
                successMessage = "Message sent"
                loadThreads()
            case .error(let message, _):
                isSending = false
                errorMessage = message
            case .loading: break
            }
        }
    }

    private func extractMentionedEmails(_ text: String) -> [String] {
        var emails: [String] = []
        let textLower = text.lowercased()
        for contractor in contractors {
            let mention = "@\(contractor.displayName)".lowercased()
            if textLower.contains(mention) && !emails.contains(contractor.email) {
                emails.append(contractor.email)
            }
        }
        return emails
    }

    func formatTimestamp(_ sentAt: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let cleaned = sentAt.replacingOccurrences(of: "Z", with: "")
        if let date = formatter.date(from: cleaned) {
            formatter.dateFormat = "MMM dd, HH:mm"
            return formatter.string(from: date)
        }
        return sentAt
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }

    func addSelectedFile(_ url: URL, fileName: String, filePath: String) {
        selectedFiles.append(SelectedFileItem(url: url, fileName: fileName, filePath: filePath))
    }

    func removeSelectedFile(_ filePath: String) {
        selectedFiles.removeAll { $0.filePath == filePath }
    }
}
