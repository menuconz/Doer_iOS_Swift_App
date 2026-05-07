import Foundation
import Alamofire

class ShiftApi {
    private let network = NetworkManager.shared

    // MARK: - Shift Retrieval

    func getAllShifts() async throws -> [ShiftDto] {
        return try await network.get("Shift/GetShifts")
    }

    func getShiftsByUserId(userId: String) async throws -> [ShiftDto] {
        return try await network.get("Shift/GetShiftsByUserId", parameters: ["userId": userId])
    }

    func getShiftsByUserIdMonth(userId: String, month: Int, year: Int) async throws -> [ShiftDto] {
        return try await network.get("Shift/GetShiftsByUserIdMonthAndYear", parameters: [
            "userId": userId, "month": month, "year": year
        ])
    }

    func getShiftsForApp(month: Int, year: Int) async throws -> [ShiftDto] {
        return try await network.get("Shift/GetShiftsForApp", parameters: ["month": month, "year": year])
    }

    func getShiftsByUserIdAndDate(userId: String, selectedDate: String) async throws -> [ShiftDto] {
        return try await network.get("Shift/GetShiftsByUserIdAndDate", parameters: [
            "userId": userId, "selectedDate": selectedDate
        ])
    }

    func getShiftsByDate(selectedDate: String) async throws -> [ShiftDto] {
        return try await network.get("Shift/GetShiftsByDate", parameters: ["selectedDate": selectedDate])
    }

    func getShiftsByCaregiverId(caregiverId: String) async throws -> [ShiftDto] {
        return try await network.get("Shift/GetShiftsByCaregiverId", parameters: ["caregiverId": caregiverId])
    }

    func getAdminJobsByAdminId(userId: String) async throws -> [ShiftDto] {
        return try await network.get("Shift/GetAdminJobsByAdminId", parameters: ["adminId": userId])
    }

    func getMonthlyJobsByUserId(userId: String, month: Int?, year: Int?, skip: Int = 0, take: Int = 100) async throws -> [ShiftDto] {
        var params: [String: Any] = ["userId": userId, "skip": skip, "take": take]
        if let month = month { params["month"] = month }
        if let year = year { params["year"] = year }
        return try await network.get("Shift/GetMonthlyJobsByUserId", parameters: params)
    }

    func getMonthlyJobsByCaregiverId(caregiverId: String, month: Int?, year: Int?, skip: Int = 0, take: Int = 100) async throws -> [ShiftDto] {
        var params: [String: Any] = ["caregiverId": caregiverId, "skip": skip, "take": take]
        if let month = month { params["month"] = month }
        if let year = year { params["year"] = year }
        return try await network.get("Shift/GetMonthlyJobsByCaregiverId", parameters: params)
    }

    func getMonthlyJobsByAdmin(month: Int?, year: Int?, skip: Int = 0, take: Int = 100) async throws -> [ShiftDto] {
        var params: [String: Any] = ["skip": skip, "take": take]
        if let month = month { params["month"] = month }
        if let year = year { params["year"] = year }
        return try await network.get("Shift/GetMonthlyJobsByAdmin", parameters: params)
    }

    // Date-based Kanban (Yesterday / Today / Next 5 Days). Returns shifts whose subitems
    // (or the shift itself) fall in [startDate, endDate].
    func getJobsByDateRange(userId: String, startDate: String, endDate: String) async throws -> [ShiftDto] {
        return try await network.get("Shift/GetJobsByDateRange", parameters: [
            "userId": userId, "startDate": startDate, "endDate": endDate
        ])
    }

    func getShiftById(id: Int) async throws -> ShiftDto {
        return try await network.get("Shift/GetShiftById", parameters: ["Id": id])
    }

    func getSortedShiftsByUserIdLocationAndTime(
        userId: String, latitude: Double, longitude: Double, durationFrom: String?, durationTo: String?
    ) async throws -> [ShiftDto] {
        var params: [String: Any] = [
            "userId": userId, "searchlatitude": latitude, "searchlongitude": longitude
        ]
        if let from = durationFrom { params["durationFrom"] = from }
        if let to = durationTo { params["durationTo"] = to }
        return try await network.get("Shift/GetFilteredShiftsByUserIdLocationAndTime", parameters: params)
    }

    // MARK: - Shift Management

    func createShift(shiftDetail: ShiftDto) async throws -> ShiftDto {
        return try await network.post("Shift/CreateShift", body: shiftDetail)
    }

    func updateShift(shiftDetail: ShiftDto) async throws -> ShiftDto {
        return try await network.post("Shift/UpdateShiftAsync", body: shiftDetail)
    }

    func updateShiftsExtraHour(shiftDetail: ShiftDto) async throws -> ShiftDto {
        return try await network.post("Shift/UpdateShiftsExtraHour", body: shiftDetail)
    }

    func requestOverTime(shift: ShiftDto) async throws -> (String, Int) {
        return try await network.postRaw("Shift/RequestForOverTime", body: shift)
    }

    func deleteJob(id: Int) async throws -> Bool {
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

    func addTaskReminder(shiftDetail: ShiftDto) async throws -> ShiftDto {
        return try await network.post("Shift/AddTaskReminderAsync", body: shiftDetail)
    }

    // MARK: - Sub-Items

    func addSubItems(shiftSubItem: ShiftSubItemDto) async throws -> ShiftSubItemDto {
        return try await network.post("Shift/CreateShiftSubItems", body: shiftSubItem)
    }

    func editSubItems(shiftSubItem: ShiftSubItemDto) async throws -> ShiftSubItemDto {
        return try await network.post("Shift/UpdateShiftSubItemAsync", body: shiftSubItem)
    }

    func getSubItemsByJobId(id: Int) async throws -> [ShiftSubItemDto] {
        return try await network.get("Shift/GetSubItemsByShiftId", parameters: ["shiftId": id])
    }

    func getSubItemById(id: Int) async throws -> ShiftSubItemDto {
        return try await network.get("Shift/GetShiftSubItemsById", parameters: ["id": id])
    }

    func deleteSubItem(id: Int) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            network.session.request(
                network.baseURL + "Shift/DeleteSubItem",
                method: .post,
                parameters: ["subItemId": id],
                encoding: URLEncoding.queryString
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

    // MARK: - Quotations

    func getQuotationsByJobId(id: Int) async throws -> [JobQuotationDto] {
        return try await network.get("Shift/GetJobQuotations", parameters: ["shiftId": id])
    }

    func getQuotationsBySearch(id: Int, latitude: Double, longitude: Double, searchSkills: String, searchName: String) async throws -> [JobQuotationDto] {
        return try await network.get("Shift/SearchJobQuotationsByLocationandSkills", parameters: [
            "shiftId": id, "searchlatitude": latitude, "searchlongitude": longitude, "skill": searchSkills, "name": searchName
        ])
    }

    func addJobQuotation(jobQuotation: JobQuotationDto) async throws -> JobQuotationDto {
        return try await network.post("Shift/AddJobQuotation", body: jobQuotation)
    }

    func getJobQuotationByContractorIdAndShiftId(contractorId: String, shiftId: Int) async throws -> JobQuotationDto {
        return try await network.get("Shift/GetJobQuotationByContractorIdAndShifId", parameters: [
            "contractorId": contractorId, "shiftId": shiftId
        ])
    }

    // MARK: - Files

    func getShiftFiles(shiftId: String) async throws -> [FileUploadModelDto] {
        return try await network.get("Shift/GetFilesByShiftId/\(shiftId)")
    }

    func getSubItemFiles(shiftId: String, subItemId: String) async throws -> [FileUploadModelDto] {
        return try await network.get("Shift/GetFiles", parameters: ["shiftId": shiftId, "subItemId": subItemId])
    }

    func uploadFile(
        fields: [String: String],
        files: [(data: Data, name: String, fileName: String, mimeType: String)]
    ) async throws -> FileUploadResponseDto {
        return try await network.upload("Shift/UploadFilesToShift", fields: fields, files: files)
    }

    // MARK: - Notifications

    func getUserAllNotificationsById(userId: String) async throws -> [NotificationsDto] {
        return try await network.get("Shift/getUserAllNotificationsById", parameters: ["id": userId])
    }

    func markNotificationAsRead(id: Int) async throws -> NotificationsDto {
        return try await network.get("Shift/MarkNotificationAsRead", parameters: ["id": id])
    }

    // MARK: - Users by Job

    func getAllUsersByJobId(jobId: Int) async throws -> [UserDto] {
        return try await network.get("Shift/GetAllUsersByJobId", parameters: ["jobId": jobId])
    }
}
