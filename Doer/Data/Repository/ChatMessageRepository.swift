import Foundation

class ChatMessageRepository {
    private let chatApi: ChatMessageApi

    init(chatApi: ChatMessageApi = ChatMessageApi()) {
        self.chatApi = chatApi
    }

    func sendChatMessage(message: ChatMessageModelDto) async -> ApiResult<Bool> {
        await safeApiCall { try await self.chatApi.sendChatMessage(message: message) }
    }

    func getChatMessageByShiftId(shiftId: Int) async -> ApiResult<[ChatMessageModelDto]> {
        await safeApiCall { try await self.chatApi.getChatMessageByShiftId(shiftId: shiftId) }
    }
}
