import Foundation

// MARK: - ShiftStatus
enum ShiftStatus: Int, Codable {
    case created = 1
    case accepted = 2
    case ongoing = 3
    case completed = 4
    case notCompleted = 5
    case finishJob = 6

    static func fromValue(_ value: Int) -> ShiftStatus {
        return ShiftStatus(rawValue: value) ?? .created
    }
}

// MARK: - UserRole
enum UserRole: String, Codable {
    case administrator = "ADMINISTRATOR"
    case manager = "MANAGER"
    case contractor = "CONTRACTOR"
    case customer = "CUSTOMER"

    static func fromName(_ name: String) -> UserRole {
        return UserRole(rawValue: name.uppercased()) ?? .contractor
    }
}

// MARK: - Invoice
enum Invoice: Int, Codable {
    case notYetCreated = 1
    case toBeInvoiced = 2
    case invoiceDrafted = 3
    case invoiceSent = 4

    static func fromValue(_ value: Int) -> Invoice {
        return Invoice(rawValue: value) ?? .notYetCreated
    }
}

// MARK: - ContractType
enum ContractType: Int, Codable {
    case toBeConfirmed = 1
    case fullContract = 2
    case supplyPlaceAndFinish = 3
    case placeAndFinish = 4
    case labourSupply = 5
    case boxPlaceAndFinish = 6
    case remedial = 7
    case supplyPlaceFinishAndCut = 8
    case placeFinishAndCut = 9
    case otherServices = 10
    case meetings = 11

    static func fromValue(_ value: Int) -> ContractType {
        return ContractType(rawValue: value) ?? .toBeConfirmed
    }
}

// MARK: - SubItemStatus
enum SubItemStatus: Int, Codable {
    case awaitingPrevious = 1
    case workingOnIt = 2
    case stuck = 3
    case done = 4

    static func fromValue(_ value: Int) -> SubItemStatus {
        return SubItemStatus(rawValue: value) ?? .awaitingPrevious
    }
}

// MARK: - JobCategory
enum JobCategory: Int, Codable {
    case primary = 1
    case secondary = 2

    static func fromValue(_ value: Int) -> JobCategory {
        return JobCategory(rawValue: value) ?? .primary
    }

    func toDisplayString() -> String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        }
    }
}

// MARK: - HSRequiredStatus
enum HSRequiredStatus: Int, Codable {
    case noHS = 0
    case sssp = 1
    case jsa = 2
    case take5 = 3
    case done = 4
    case missingHS = 5

    static func fromValue(_ value: Int) -> HSRequiredStatus {
        return HSRequiredStatus(rawValue: value) ?? .noHS
    }
}

// MARK: - LeadStatus
enum LeadStatus: Int, Codable {
    case newLead = 1
    case quoteSent = 2
    case won = 3
    case contacted = 4
    case quoteExpired = 5
    case drafted = 6

    static func fromValue(_ value: Int) -> LeadStatus {
        return LeadStatus(rawValue: value) ?? .newLead
    }
}

// MARK: - NotificationStatus
enum NotificationStatus: Int, Codable {
    case pending = 0
    case sent = 1
    case delivered = 2
    case failed = 3
    case read = 4

    static func fromValue(_ value: Int) -> NotificationStatus {
        return NotificationStatus(rawValue: value) ?? .sent
    }
}

// MARK: - FrontEndPageVisibility
enum FrontEndPageVisibility: Int, Codable {
    case showAgreement = 1
    case showInformation = 2
    case showWelcomeScreen = 3
}

// MARK: - ControlType
enum ControlType: String, Codable {
    case textField
    case dropdownList
    case radioButton
    case datePicker
    case checkBox
    case numericTextField
    case textLabel
    case textKeyValueRadio
}

// MARK: - MultipleUploadDocumentType
enum MultipleUploadDocumentType: String, Codable {
    case image
    case document
    case externalLink
    case video
}

// MARK: - FilterColumnType
enum FilterColumnType: String, Codable {
    case itemColumn
    case subItemColumn
}

// MARK: - FilterCondition
enum FilterCondition: String, Codable {
    case contains = "Contains"
    case doesNotContain = "DoesNotContain"
    case startsWith = "StartsWith"
    case `is` = "Is"
    case isNot = "IsNot"
    case isEmpty = "IsEmpty"
    case isNotEmpty = "IsNotEmpty"
    case equals = "Equals"
    case notEquals = "NotEquals"
    case greaterThan = "GreaterThan"
    case lessThan = "LessThan"
    case greaterThanOrEqual = "GreaterThanOrEqual"
    case lessThanOrEqual = "LessThanOrEqual"

    func toDisplayString() -> String {
        switch self {
        case .contains: return "Contains"
        case .doesNotContain: return "Does Not Contain"
        case .startsWith: return "Starts With"
        case .is: return "Is"
        case .isNot: return "Is Not"
        case .isEmpty: return "Is Empty"
        case .isNotEmpty: return "Is Not Empty"
        case .equals: return "Equals"
        case .notEquals: return "Not Equals"
        case .greaterThan: return "Greater Than"
        case .lessThan: return "Less Than"
        case .greaterThanOrEqual: return "Greater Than or Equal"
        case .lessThanOrEqual: return "Less Than or Equal"
        }
    }
}
