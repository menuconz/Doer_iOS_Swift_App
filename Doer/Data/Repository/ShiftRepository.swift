import Foundation

class ShiftRepository {
    private let shiftApi: ShiftApi
    private let prefs: PreferencesManager

    init(shiftApi: ShiftApi = ShiftApi(), prefs: PreferencesManager = .shared) {
        self.shiftApi = shiftApi
        self.prefs = prefs
    }

    func getAllShifts() async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getAllShifts() } }
    func getShiftsByUserId(userId: String) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getShiftsByUserId(userId: userId) } }
    func getShiftsByUserIdMonth(userId: String, month: Int, year: Int) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getShiftsByUserIdMonth(userId: userId, month: month, year: year) } }
    func getShiftsForApp(month: Int, year: Int) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getShiftsForApp(month: month, year: year) } }
    func getShiftsByUserIdAndDate(userId: String, selectedDate: String) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getShiftsByUserIdAndDate(userId: userId, selectedDate: selectedDate) } }
    func getShiftsByDate(selectedDate: String) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getShiftsByDate(selectedDate: selectedDate) } }
    func getShiftsByCaregiverId(caregiverId: String) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getShiftsByCaregiverId(caregiverId: caregiverId) } }
    func getAdminJobsByAdminId(userId: String) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getAdminJobsByAdminId(userId: userId) } }
    func getMonthlyJobsByUserId(userId: String, month: Int?, year: Int?, skip: Int = 0, take: Int = 100) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getMonthlyJobsByUserId(userId: userId, month: month, year: year, skip: skip, take: take) } }
    func getMonthlyJobsByCaregiverId(caregiverId: String, month: Int?, year: Int?, skip: Int = 0, take: Int = 100) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getMonthlyJobsByCaregiverId(caregiverId: caregiverId, month: month, year: year, skip: skip, take: take) } }
    func getMonthlyJobsByAdmin(month: Int?, year: Int?, skip: Int = 0, take: Int = 100) async -> ApiResult<[ShiftDto]> { await safeApiCall { try await self.shiftApi.getMonthlyJobsByAdmin(month: month, year: year, skip: skip, take: take) } }
    func getShiftById(id: Int) async -> ApiResult<ShiftDto> { await safeApiCall { try await self.shiftApi.getShiftById(id: id) } }

    func createShift(shiftDetail: ShiftDto) async -> ApiResult<ShiftDto> { await safeApiCall { try await self.shiftApi.createShift(shiftDetail: shiftDetail) } }
    func updateShift(shiftDetail: ShiftDto) async -> ApiResult<ShiftDto> { await safeApiCall { try await self.shiftApi.updateShift(shiftDetail: shiftDetail) } }
    func updateShiftsExtraHour(shiftDetail: ShiftDto) async -> ApiResult<ShiftDto> { await safeApiCall { try await self.shiftApi.updateShiftsExtraHour(shiftDetail: shiftDetail) } }
    func requestOverTime(shift: ShiftDto) async -> ApiResult<(String, Int)> { await safeApiCall { try await self.shiftApi.requestOverTime(shift: shift) } }
    func deleteJob(id: Int) async -> ApiResult<Bool> { await safeApiCall { try await self.shiftApi.deleteJob(id: id) } }
    func addTaskReminder(shiftDetail: ShiftDto) async -> ApiResult<ShiftDto> { await safeApiCall { try await self.shiftApi.addTaskReminder(shiftDetail: shiftDetail) } }

    // Sub-Items
    func addSubItems(subItem: ShiftSubItemDto) async -> ApiResult<ShiftSubItemDto> { await safeApiCall { try await self.shiftApi.addSubItems(shiftSubItem: subItem) } }
    func editSubItems(subItem: ShiftSubItemDto) async -> ApiResult<ShiftSubItemDto> { await safeApiCall { try await self.shiftApi.editSubItems(shiftSubItem: subItem) } }
    func getSubItemsByJobId(id: Int) async -> ApiResult<[ShiftSubItemDto]> { await safeApiCall { try await self.shiftApi.getSubItemsByJobId(id: id) } }
    func getSubItemById(id: Int) async -> ApiResult<ShiftSubItemDto> { await safeApiCall { try await self.shiftApi.getSubItemById(id: id) } }
    func deleteSubItem(id: Int) async -> ApiResult<Bool> { await safeApiCall { try await self.shiftApi.deleteSubItem(id: id) } }

    // Quotations
    func getQuotationsByJobId(id: Int) async -> ApiResult<[JobQuotationDto]> { await safeApiCall { try await self.shiftApi.getQuotationsByJobId(id: id) } }
    func getQuotationsBySearch(shiftId: Int, latitude: Double, longitude: Double, searchSkills: String, searchName: String) async -> ApiResult<[JobQuotationDto]> { await safeApiCall { try await self.shiftApi.getQuotationsBySearch(id: shiftId, latitude: latitude, longitude: longitude, searchSkills: searchSkills, searchName: searchName) } }
    func addJobQuotation(quotation: JobQuotationDto) async -> ApiResult<JobQuotationDto> { await safeApiCall { try await self.shiftApi.addJobQuotation(jobQuotation: quotation) } }
    func getJobQuotationByContractorIdAndShiftId(contractorId: String, shiftId: Int) async -> ApiResult<JobQuotationDto> { await safeApiCall { try await self.shiftApi.getJobQuotationByContractorIdAndShiftId(contractorId: contractorId, shiftId: shiftId) } }

    // Files
    func getShiftFiles(shiftId: String) async -> ApiResult<[FileUploadModelDto]> { await safeApiCall { try await self.shiftApi.getShiftFiles(shiftId: shiftId) } }
    func getSubItemFiles(shiftId: String, subItemId: String) async -> ApiResult<[FileUploadModelDto]> { await safeApiCall { try await self.shiftApi.getSubItemFiles(shiftId: shiftId, subItemId: subItemId) } }

    func uploadFile(shiftId: String, subItemId: String?, files: [(data: Data, fileName: String)]) async -> ApiResult<FileUploadResponseDto> {
        return await safeApiCall {
            var fields: [String: String] = [:]
            fields["ShiftId"] = shiftId
            if let subItemId = subItemId, !subItemId.isEmpty {
                fields["ShiftSubItemId"] = subItemId
            }
            fields["CreatedBy"] = self.prefs.userId
            fields["SiteId"] = "1"
            fields["LId"] = "1"
            fields["UserID"] = self.prefs.userId
            fields["BasicAuthUid"] = self.prefs.basicAuthUid

            let fileParts = files.map { file in
                (data: file.data, name: "Files", fileName: file.fileName, mimeType: NetworkManager.getMimeType(file.fileName))
            }

            return try await self.shiftApi.uploadFile(fields: fields, files: fileParts)
        }
    }

    // Notifications
    func getUserAllNotificationsById(userId: String) async -> ApiResult<[NotificationsDto]> { await safeApiCall { try await self.shiftApi.getUserAllNotificationsById(userId: userId) } }
    func markNotificationAsRead(id: Int) async -> ApiResult<NotificationsDto> { await safeApiCall { try await self.shiftApi.markNotificationAsRead(id: id) } }

    // Users by Job
    func getAllUsersByJobId(jobId: Int) async -> ApiResult<[UserDto]> { await safeApiCall { try await self.shiftApi.getAllUsersByJobId(jobId: jobId) } }
}
