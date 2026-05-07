import Foundation
import SwiftUI

@Observable
@MainActor
class BoardSettingsViewModel {
    private let repository: BoardRepository
    private let cache: BoardConfigCache

    var isLoading: Bool = false
    var board: BoardDto? = nil
    var boardNameDraft: String = ""
    var optionsByColumn: [String: [DropdownOptionDto]] = [:]
    var expandedColumns: Set<String> = []
    var editing: DropdownOptionDto? = nil
    var pendingDelete: DropdownOptionDto? = nil
    var errorMessage: String? = nil
    var successMessage: String? = nil

    init(
        repository: BoardRepository = DIContainer.shared.boardRepository,
        cache: BoardConfigCache = DIContainer.shared.boardConfigCache
    ) {
        self.repository = repository
        self.cache = cache
    }

    func load() {
        isLoading = true
        errorMessage = nil
        Task { @MainActor in
            switch await repository.getBoards() {
            case .success(let boards):
                guard let active = boards.first(where: { $0.isActive }) else {
                    isLoading = false
                    errorMessage = "No active board found."
                    return
                }
                board = active
                boardNameDraft = active.name
                switch await repository.getDropdownOptions(boardId: active.id, columnName: nil) {
                case .success(let options):
                    let activeOpts = options.filter { $0.isActive }
                    optionsByColumn = Dictionary(grouping: activeOpts, by: { $0.columnName })
                        .mapValues { $0.sorted { $0.sortOrder < $1.sortOrder } }
                case .error(let msg, _):
                    errorMessage = msg
                case .loading: break
                }
                isLoading = false
            case .error(let msg, _):
                isLoading = false
                errorMessage = msg
            case .loading:
                break
            }
        }
    }

    func saveBoardName() {
        guard let board = board else { return }
        let newName = boardNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != board.name else { return }

        Task { @MainActor in
            switch await repository.updateBoard(id: board.id, name: newName) {
            case .success(let updated):
                self.board = updated
                self.boardNameDraft = updated.name
                self.successMessage = "Board name updated."
                await cache.load()
            case .error(let msg, _):
                self.errorMessage = msg
            case .loading: break
            }
        }
    }

    func toggleColumn(_ columnName: String) {
        if expandedColumns.contains(columnName) {
            expandedColumns.remove(columnName)
        } else {
            expandedColumns.insert(columnName)
        }
    }

    func beginEdit(_ option: DropdownOptionDto) {
        editing = option
    }

    // Open the editor with a fresh option (id=0 → server creates new on save).
    func beginAdd(columnName: String) {
        guard let board = board else { return }
        let existing = optionsByColumn[columnName] ?? []
        let nextValue = (existing.map { $0.value }.max() ?? 0) + 1
        let nextSort = existing.count + 1
        editing = DropdownOptionDto(
            id: 0,
            boardId: board.id,
            columnName: columnName,
            value: nextValue,
            displayName: "",
            color: "#1976D2",
            sortOrder: nextSort,
            isActive: true
        )
    }

    func updateEditField(displayName: String? = nil, color: String? = nil, sortOrder: Int? = nil) {
        guard var current = editing else { return }
        if let v = displayName { current.displayName = v }
        if let v = color { current.color = v }
        if let v = sortOrder { current.sortOrder = v }
        editing = current
    }

    func cancelEdit() {
        editing = nil
    }

    func saveEdit() {
        guard let edited = editing, let board = board else { return }
        let trimmed = edited.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMessage = "Display Name cannot be empty."
            return
        }
        let isNew = edited.id == 0
        Task { @MainActor in
            switch await repository.upsertDropdownOption(boardId: board.id, option: edited) {
            case .success(let saved):
                let existing = optionsByColumn[saved.columnName] ?? []
                let updatedList: [DropdownOptionDto]
                if isNew {
                    updatedList = (existing + [saved]).sorted { $0.sortOrder < $1.sortOrder }
                } else {
                    updatedList = existing.map { $0.id == saved.id ? saved : $0 }
                        .sorted { $0.sortOrder < $1.sortOrder }
                }
                var newGrouped = optionsByColumn
                newGrouped[saved.columnName] = updatedList
                optionsByColumn = newGrouped
                editing = nil
                successMessage = isNew ? "Option added." : "Saved."
                await cache.refreshDropdowns(boardId: board.id)
            case .error(let msg, _):
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func confirmDelete(_ option: DropdownOptionDto) {
        pendingDelete = option
    }

    func cancelDelete() {
        pendingDelete = nil
    }

    // Soft delete: send the option back with isActive = false. Server upsert
    // updates the row and the cache filter (isActive only) hides it.
    func deleteOption() {
        guard let target = pendingDelete, let board = board else { return }
        var payload = target
        payload.isActive = false
        Task { @MainActor in
            switch await repository.upsertDropdownOption(boardId: board.id, option: payload) {
            case .success:
                var newGrouped = optionsByColumn
                newGrouped[target.columnName] = (newGrouped[target.columnName] ?? []).filter { $0.id != target.id }
                optionsByColumn = newGrouped
                pendingDelete = nil
                successMessage = "Option deleted."
                await cache.refreshDropdowns(boardId: board.id)
            case .error(let msg, _):
                pendingDelete = nil
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }
}
