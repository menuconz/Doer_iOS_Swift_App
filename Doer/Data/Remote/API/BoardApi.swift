import Foundation
import Alamofire

class BoardApi {
    private let network = NetworkManager.shared

    func getBoards() async throws -> [BoardDto] {
        return try await network.get("Board")
    }

    func getBoardById(id: Int) async throws -> BoardDto {
        return try await network.get("Board/\(id)")
    }

    func updateBoard(id: Int, body: UpdateBoardDto) async throws -> BoardDto {
        return try await network.put("Board/\(id)", body: body)
    }

    func getDropdownOptions(boardId: Int, columnName: String? = nil) async throws -> [DropdownOptionDto] {
        var params: [String: Any] = [:]
        if let cn = columnName, !cn.isEmpty { params["columnName"] = cn }
        return try await network.get("Board/\(boardId)/dropdown-options", parameters: params)
    }

    func upsertDropdownOption(boardId: Int, option: DropdownOptionDto) async throws -> DropdownOptionDto {
        return try await network.post("Board/\(boardId)/dropdown-options", body: option)
    }
}
