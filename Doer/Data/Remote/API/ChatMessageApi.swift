import Foundation

class ChatMessageApi {
    private let network = NetworkManager.shared

    func sendChatMessage(message: ChatMessageModelDto) async throws -> Bool {
        return try await network.postBool("ChatMessage/SendChatMessage", body: message)
    }

    func getChatMessageByShiftId(shiftId: Int) async throws -> [ChatMessageModelDto] {
        return try await network.get("ChatMessage/GetChatMessages", parameters: ["shiftId": shiftId])
    }
}
