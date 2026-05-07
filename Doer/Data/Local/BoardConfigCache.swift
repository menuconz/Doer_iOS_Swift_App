import Foundation
import SwiftUI

// In-memory cache for the active Board and its DropdownOptions.
// Loaded at app start and refreshed when admin saves an edit.
// Falls back to hardcoded enum labels when the cache hasn't loaded yet so the UI
// never shows blank labels even before the network call completes.
@Observable
class BoardConfigCache {
    private let boardRepository: BoardRepository

    var activeBoard: BoardDto? = nil
    // Map<ColumnName, [DropdownOptionDto]> sorted by SortOrder
    var optionsByColumn: [String: [DropdownOptionDto]] = [:]

    // Bumps whenever options change so UI can react via this id.
    var version: Int = 0

    init(boardRepository: BoardRepository) {
        self.boardRepository = boardRepository
    }

    @MainActor
    func load() async {
        switch await boardRepository.getBoards() {
        case .success(let boards):
            guard let board = boards.first(where: { $0.isActive }) else { return }
            self.activeBoard = board
            await refreshDropdowns(boardId: board.id)
        default:
            break // silent fail — fallback labels still work
        }
    }

    @MainActor
    func refreshDropdowns(boardId: Int) async {
        switch await boardRepository.getDropdownOptions(boardId: boardId, columnName: nil) {
        case .success(let options):
            let active = options.filter { $0.isActive }
            self.optionsByColumn = Dictionary(grouping: active, by: { $0.columnName })
                .mapValues { $0.sorted { $0.sortOrder < $1.sortOrder } }
            self.version &+= 1
        default:
            break
        }
    }

    // Returns options for a column, or empty if cache hasn't loaded.
    func getOptions(_ columnName: String) -> [DropdownOptionDto] {
        return optionsByColumn[columnName] ?? []
    }

    // Returns the display label for a value, or [fallback] if not in cache.
    func displayName(_ columnName: String, value: Int, fallback: @autoclosure () -> String) -> String {
        if let opt = optionsByColumn[columnName]?.first(where: { $0.value == value }) {
            return opt.displayName
        }
        return fallback()
    }

    // Returns the colour (UInt32 ARGB) for a value, or [fallbackColor] if not cached.
    func color(_ columnName: String, value: Int, fallback: @autoclosure () -> UInt32) -> UInt32 {
        if let hex = optionsByColumn[columnName]?.first(where: { $0.value == value })?.color,
           let parsed = Self.parseHexColor(hex) {
            return parsed
        }
        return fallback()
    }

    // Returns the active board name or a default if not loaded.
    func boardName(default fallback: String = "NZ Mahi 2026") -> String {
        return activeBoard?.name ?? fallback
    }

    func boardId() -> Int? {
        return activeBoard?.id
    }

    // Parses "#RRGGBB" or "RRGGBB" into UInt32 ARGB (alpha=FF).
    static func parseHexColor(_ hex: String?) -> UInt32? {
        guard let raw = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        let cleaned = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        guard cleaned.count == 6, let rgb = UInt32(cleaned, radix: 16) else { return nil }
        return 0xFF000000 | (rgb & 0xFFFFFF)
    }
}

// SwiftUI Color helpers so cache-derived colours can be rendered directly.
extension Color {
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
