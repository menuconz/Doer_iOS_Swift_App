import Foundation

struct BoardDto: Codable, Identifiable, Hashable {
    var id: Int = 0
    var name: String = ""
    var isActive: Bool = true
    var createdDate: String? = nil
    var modifiedDate: String? = nil
}

struct UpdateBoardDto: Codable {
    var name: String
}

struct DropdownOptionDto: Codable, Identifiable, Hashable {
    var id: Int = 0
    var boardId: Int = 0
    var columnName: String = ""
    var value: Int = 0
    var displayName: String = ""
    var color: String? = nil
    var sortOrder: Int = 0
    var isActive: Bool = true
}
