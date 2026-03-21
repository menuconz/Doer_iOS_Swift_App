import Foundation
import Alamofire

class LeadApi {
    private let network = NetworkManager.shared

    func getLeads() async throws -> [LeadsDto] {
        return try await network.get("Lead/GetLeads")
    }

    func getNewLeads() async throws -> [LeadsDto] {
        return try await network.get("Lead/GetNewLeads")
    }

    func getQuotedAndWonLeads() async throws -> [LeadsDto] {
        return try await network.get("Lead/GetQuotedAndWonLeads")
    }

    func getContactedLeads() async throws -> [LeadsDto] {
        return try await network.get("Lead/GetContactedLeads")
    }

    func createNewLead(leadDetail: LeadsDto) async throws -> LeadsDto {
        return try await network.post("Lead/CreateLead", body: leadDetail)
    }

    func updateLead(leadDetail: LeadsDto) async throws -> LeadsDto {
        return try await network.post("Lead/UpdateLead", body: leadDetail)
    }

    func sendFollowUpMailToClient(id: Int) async throws -> Int {
        return try await network.getInt("Lead/SendFollowUPMailToClient", parameters: ["leadId": id])
    }

    func getShiftById(id: Int) async throws -> ShiftDto {
        return try await network.get("Shift/GetShiftById", parameters: ["Id": id])
    }

    func deleteJobById(id: Int) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            network.session.request(
                network.baseURL + "Shift/DeleteShift",
                method: .post,
                parameters: ["Id": id],
                encoding: URLEncoding.default
            )
            .validate()
            .responseDecodable(of: Bool.self) { response in
                switch response.result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}
