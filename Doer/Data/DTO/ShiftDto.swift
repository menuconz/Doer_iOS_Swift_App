import Foundation

struct ShiftDto: Codable, Identifiable, Hashable {
    var id: Int = 0
    var caregiverId: String = ""
    var statusId: Int = 0
    var durationFrom: String = ""
    var durationTo: String = ""
    var address: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var instructions: String = ""
    var activateNow: Bool = false
    var activateLater: Bool = false
    var shiftActivateTime: String? = nil
    var shiftStartTime: String? = nil
    var shiftEndTime: String? = nil
    var isOverTime: Bool = false
    var extraHours: Double = 0.0
    var feedback: String = ""
    var createdBy: String = ""
    var createdByIp: String = ""
    var createdDate: String? = nil
    var modifiedBy: String = ""
    var modifiedByIp: String = ""
    var modifiedDate: String? = nil
    var caregiverName: String? = nil
    var caregiverEmail: String? = nil
    var caregiverPhone: String? = nil
    var caregiverAddress: String? = nil
    var durationFromString: String = ""
    var durationToString: String = ""
    var statusMessage: String = ""
    var statusColor: String = ""
    var amount: Double? = nil
    var actualInvoiceAmount: Double? = nil // Editable by Admin/Manager only
    var caregiverLevelId: Int? = nil
    var caregiverLevelName: String? = nil
    var paymarkPaymentUrl: String = ""
    var isPaymentDone: Bool = false
    var jobQuotations: [JobQuotationDto]? = nil
    var hasQuotations: Bool = false
    var contractorResponseToReview: String = ""
    var projectName: String = ""
    var contractType: Int? = nil
    var invoiceStatus: Int? = nil
    var invoiceStatusText: String = ""
    var contractTypeText: String = ""
    var hsForms: Int? = nil
    var hsForm: String = ""
    var finalMeasure: String = ""
    var reminderOffset: String? = nil
    var reminderTime: String? = nil
    var isReminderScheduled: Bool = false
    var isReminderSent: Bool = false
    var reminderSentAt: String? = nil
    var shiftSubItems: [ShiftSubItemDto]? = nil
    var adminId: String = ""
    var isAllDay: Bool = false
    var clientId: Int? = nil
    var clientName: String? = nil
    var acceptedQuoteAmount: Double? = nil
    var acceptedQuotationId: Int? = nil
    var isContractor: Bool = false
    // EntityBase fields
    var lId: Int = 0
    var siteId: Int = 1
    var contactId: Int = 0
    var userId: String? = nil
    var errorMessage: String? = nil
    var status: Bool = false
    var basicAuthUid: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case caregiverId
        case statusId
        case durationFrom
        case durationTo
        case address
        case latitude
        case longitude
        case instructions
        case activateNow
        case activateLater
        case shiftActivateTime
        case shiftStartTime
        case shiftEndTime
        case isOverTime
        case extraHours
        case feedback
        case createdBy
        case createdByIp = "createdByIP"
        case createdDate
        case modifiedBy
        case modifiedByIp = "modifiedByIP"
        case modifiedDate
        case caregiverName
        case caregiverEmail
        case caregiverPhone
        case caregiverAddress
        case durationFromString
        case durationToString
        case statusMessage
        case statusColor
        case amount
        case actualInvoiceAmount
        case caregiverLevelId
        case caregiverLevelName
        case paymarkPaymentUrl = "paymarkPaymentURL"
        case isPaymentDone
        case jobQuotations
        case hasQuotations
        case contractorResponseToReview = "contractorResponsetoReview"
        case projectName
        case contractType
        case invoiceStatus
        case invoiceStatusText
        case contractTypeText
        case hsForms
        case hsForm
        case finalMeasure
        case reminderOffset
        case reminderTime
        case isReminderScheduled
        case isReminderSent
        case reminderSentAt
        case shiftSubItems
        case adminId
        case isAllDay
        case clientId
        case clientName
        case acceptedQuoteAmount
        case acceptedQuotationId
        case isContractor
        case lId
        case siteId
        case contactId = "contactID"
        case userId
        case errorMessage
        case status
        case basicAuthUid
    }

    static func == (lhs: ShiftDto, rhs: ShiftDto) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
