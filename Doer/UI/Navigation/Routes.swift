import Foundation

enum Route: Hashable {
    // Auth
    case loading
    case login
    case registerContractor
    case registerRestHome
    case forgotPassword
    case generateOTP(email: String)

    // Calendar
    case calendar
    case dayTimeline(date: String)
    case dayDetail(date: String, shiftId: Int? = nil)
    case shiftDetails(shiftId: Int)
    case addShift(date: String? = nil, hour: Int? = nil)
    case editShift(shiftId: Int)

    // Files
    case shiftFiles(shiftId: Int)
    case subItemFiles(shiftId: Int, subItemId: Int)
    case viewDocument(fileUrl: String, isImage: Bool)
    case viewEmailDocument(fileUrl: String)

    // Messages
    case emailMessages(shiftId: Int)
    case subItemMessages(shiftId: Int, subItemId: Int)

    // Leads
    case newLeads
    case quotedLeads
    case contactedLeads
    case addNewLead
    case leadDetail(leadId: Int)

    // Clients
    case clients
    case addNewClient

    // Contractors
    case allContractors
    case contractorDetails(contractorId: String)

    // Quotations
    case sendQuote(shiftId: Int)
    case viewQuotations(shiftId: Int)

    // Profile
    case profile
    case editProfile

    // Notifications
    case notifications

    // Feedback
    case sendFeedback(shiftId: Int)
    case reviews(shiftId: Int)

    // Admin
    case mainLeadsJobs
    case filoKretoTeam

    // Tracking
    case liveTracking
    case timeTracking
    case navigationMap(siteLatitude: Double, siteLongitude: Double, siteAddress: String, projectName: String, shiftId: Int)

    // Board / Activity
    case boardSettings
    case activityLog
}
