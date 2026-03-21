import Foundation

class LeadRepository {
    private let leadApi: LeadApi

    init(leadApi: LeadApi = LeadApi()) {
        self.leadApi = leadApi
    }

    func getLeads() async -> ApiResult<[LeadsDto]> { await safeApiCall { try await self.leadApi.getLeads() } }
    func getNewLeads() async -> ApiResult<[LeadsDto]> { await safeApiCall { try await self.leadApi.getNewLeads() } }
    func getQuotedAndWonLeads() async -> ApiResult<[LeadsDto]> { await safeApiCall { try await self.leadApi.getQuotedAndWonLeads() } }
    func getContactedLeads() async -> ApiResult<[LeadsDto]> { await safeApiCall { try await self.leadApi.getContactedLeads() } }
    func createNewLead(leadDetail: LeadsDto) async -> ApiResult<LeadsDto> { await safeApiCall { try await self.leadApi.createNewLead(leadDetail: leadDetail) } }
    func updateLead(leadDetail: LeadsDto) async -> ApiResult<LeadsDto> { await safeApiCall { try await self.leadApi.updateLead(leadDetail: leadDetail) } }
    func sendFollowUpMailToClient(id: Int) async -> ApiResult<Int> { await safeApiCall { try await self.leadApi.sendFollowUpMailToClient(id: id) } }
    func getShiftById(id: Int) async -> ApiResult<ShiftDto> { await safeApiCall { try await self.leadApi.getShiftById(id: id) } }
    func deleteJobById(id: Int) async -> ApiResult<Bool> { await safeApiCall { try await self.leadApi.deleteJobById(id: id) } }
}
