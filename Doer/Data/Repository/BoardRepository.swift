import Foundation

class BoardRepository {
    private let boardApi: BoardApi

    init(boardApi: BoardApi = BoardApi()) {
        self.boardApi = boardApi
    }

    func getBoards() async -> ApiResult<[BoardDto]> {
        await safeApiCall { try await self.boardApi.getBoards() }
    }

    func getBoardById(id: Int) async -> ApiResult<BoardDto> {
        await safeApiCall { try await self.boardApi.getBoardById(id: id) }
    }

    func updateBoard(id: Int, name: String) async -> ApiResult<BoardDto> {
        await safeApiCall { try await self.boardApi.updateBoard(id: id, body: UpdateBoardDto(name: name)) }
    }

    func getDropdownOptions(boardId: Int, columnName: String? = nil) async -> ApiResult<[DropdownOptionDto]> {
        await safeApiCall { try await self.boardApi.getDropdownOptions(boardId: boardId, columnName: columnName) }
    }

    func upsertDropdownOption(boardId: Int, option: DropdownOptionDto) async -> ApiResult<DropdownOptionDto> {
        await safeApiCall { try await self.boardApi.upsertDropdownOption(boardId: boardId, option: option) }
    }
}
