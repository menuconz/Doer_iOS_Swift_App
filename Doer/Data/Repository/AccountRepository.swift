import Foundation

class AccountRepository {
    private let accountApi: AccountApi
    private let prefs: PreferencesManager

    init(accountApi: AccountApi = AccountApi(), prefs: PreferencesManager = .shared) {
        self.accountApi = accountApi
        self.prefs = prefs
    }

    func authenticate(userName: String, password: String, deviceToken: String, deviceTypeId: Int = 2) async -> ApiResult<UserDto> {
        do {
            let body = LoginRequestDto(email: userName, password: password, deviceToken: deviceToken, deviceTypeId: deviceTypeId)
            print("[AUTH] Sending login request for: \(userName)")
            let (responseString, statusCode) = try await accountApi.authenticate(body: body)
            print("[AUTH] Status code: \(statusCode)")
            print("[AUTH] Response length: \(responseString.count) chars")
            print("[AUTH] Response preview: \(String(responseString.prefix(200)))")

            if statusCode < 200 || statusCode >= 300 {
                let errorMsg = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                print("[AUTH] HTTP error: \(errorMsg)")
                return .error(errorMsg.isEmpty ? "Please enter correct email or password" : errorMsg)
            }
            if responseString.isEmpty {
                print("[AUTH] Empty response")
                return .error("Please enter correct email or password")
            }

            let decoder = JSONDecoder()
            if let data = responseString.data(using: .utf8) {
                do {
                    let user = try decoder.decode(UserDto.self, from: data)
                    print("[AUTH] Decode SUCCESS - user: \(user.displayName), role: \(user.role), id: \(user.id)")
                    return .success(user)
                } catch {
                    print("[AUTH] Decode FAILED: \(error)")
                    return .error("Login failed. Please try again.")
                }
            } else {
                print("[AUTH] Failed to convert response to data")
                return .error("Login failed. Please try again.")
            }
        } catch {
            print("[AUTH] Network error: \(error)")
            return .error(error.localizedDescription, error)
        }
    }

    func logout(userId: String) async -> ApiResult<UserDto> {
        return await safeApiCall { try await self.accountApi.logout(userId: userId) }
    }

    func generateOtp(email: String) async -> ApiResult<UserDto> {
        return await safeApiCall { try await self.accountApi.generateOtp(email: email) }
    }

    func forgotPassword(email: String, otp: String, password: String) async -> ApiResult<Bool> {
        return await safeApiCall { try await self.accountApi.forgotPassword(otp: otp, email: email, password: password) }
    }

    func checkEmailExists(email: String) async -> ApiResult<Bool> {
        return await safeApiCall { try await self.accountApi.checkEmailExists(email: email) }
    }

    func contactDetails(contactus: ContactusDto) async -> ApiResult<Bool> {
        return await safeApiCall { try await self.accountApi.contactDetails(contactus: contactus) }
    }

    func registerManager(registerUser: RegisterUserWithoutDocumentDto) async -> ApiResult<UserDto> {
        do {
            let (responseString, statusCode) = try await accountApi.registerManager(registerUser: registerUser)
            if statusCode < 200 || statusCode >= 300 {
                let errorMsg = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return .error(errorMsg.isEmpty ? "Registration failed. Please try again." : errorMsg)
            }
            let decoder = JSONDecoder()
            if let data = responseString.data(using: .utf8),
               let user = try? decoder.decode(UserDto.self, from: data) {
                return .success(user)
            } else {
                let errorMsg = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return .error(errorMsg)
            }
        } catch {
            return .error(error.localizedDescription, error)
        }
    }

    func registerCustomer(user: UserDto) async -> ApiResult<UserDto> {
        return await safeApiCall { try await self.accountApi.registerCustomer(user: user) }
    }

    func registerContractor(user: UserDto, documentFiles: [(data: Data, fileName: String)]) async -> ApiResult<UserDto> {
        do {
            var fields: [String: String] = [:]
            fields["DisplayName"] = user.displayName
            fields["Email"] = user.email
            fields["Password"] = user.password
            fields["PhoneNumber"] = user.phoneNumber
            fields["DeviceToken"] = user.deviceToken
            fields["DeviceTypeId"] = "2"
            fields["Address"] = user.address
            fields["DateofBirth"] = user.dateOfBirthString
            fields["SiteId"] = "1"
            fields["LId"] = "1"

            let documents = documentFiles.map { file in
                (data: file.data, name: "Documents", fileName: file.fileName, mimeType: NetworkManager.getMimeType(file.fileName))
            }

            let (responseString, statusCode) = try await accountApi.registerContractor(fields: fields, documents: documents)
            if statusCode < 200 || statusCode >= 300 {
                let errorMsg = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return .error(errorMsg.isEmpty ? "Registration failed. Please try again." : errorMsg)
            }
            let decoder = JSONDecoder()
            if let data = responseString.data(using: .utf8),
               let u = try? decoder.decode(UserDto.self, from: data) {
                return .success(u)
            } else {
                let errorMsg = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return .error(errorMsg)
            }
        } catch {
            return .error(error.localizedDescription, error)
        }
    }

    func getUser(id: String) async -> ApiResult<UserDto> {
        return await safeApiCall { try await self.accountApi.getUser(id: id) }
    }

    func updateProfile(user: UserDto, newDocuments: [(data: Data, fileName: String)]) async -> ApiResult<UserDto> {
        return await safeApiCall {
            var fields: [String: String] = [:]
            fields["Id"] = user.id
            fields["DisplayName"] = user.displayName
            fields["Email"] = user.email
            fields["Username"] = user.email
            fields["PhoneNumber"] = user.phoneNumber
            fields["Address"] = user.address
            if let dob = user.dateOfBirth, !dob.isEmpty {
                fields["DateofBirth"] = dob
            }
            if let lat = user.latitude {
                fields["Latitude"] = String(lat)
            }
            if let lng = user.longitude {
                fields["Longitude"] = String(lng)
            }
            if !user.workExperience.isEmpty {
                fields["WorkExperience"] = user.workExperience
            }
            if !user.skills.isEmpty {
                fields["Skills"] = user.skills
            }
            fields["SiteId"] = "1"
            fields["LId"] = "1"
            fields["UserID"] = self.prefs.userId
            fields["BasicAuthUid"] = self.prefs.basicAuthUid

            let documents = newDocuments.map { file in
                (data: file.data, name: "AddDocument", fileName: file.fileName, mimeType: NetworkManager.getMimeType(file.fileName))
            }

            return try await self.accountApi.updateProfile(fields: fields, documents: documents)
        }
    }

    func deleteDocument(id: Int) async -> ApiResult<Bool> {
        return await safeApiCall { try await self.accountApi.deleteDocument(id: id) }
    }

    func deleteUserAccount(userId: String) async -> ApiResult<Bool> {
        return await safeApiCall { try await self.accountApi.deleteUserAccount(userId: userId) }
    }

    func markAsEmployee(userId: String, isEmployee: Bool, adminId: String) async -> ApiResult<UserDto> {
        return await safeApiCall { try await self.accountApi.markAsEmployee(userId: userId, isEmployee: isEmployee, adminId: adminId) }
    }

    func getAllContractors() async -> ApiResult<[UserDto]> {
        return await safeApiCall { try await self.accountApi.getAllContractors() }
    }

    func getAllManagers() async -> ApiResult<[UserDto]> {
        return await safeApiCall { try await self.accountApi.getAllManagers() }
    }

    func searchContractorsBySkillsAndLocation(latitude: Double, longitude: Double, searchSkills: String, searchName: String) async -> ApiResult<[UserDto]> {
        return await safeApiCall { try await self.accountApi.searchContractorsBySkillsAndLocation(latitude: latitude, longitude: longitude, searchSkills: searchSkills, searchName: searchName) }
    }

    func getAllUsersWithAdmin() async -> ApiResult<[UserDto]> {
        return await safeApiCall { try await self.accountApi.getAllUsersWithAdmin() }
    }

    func getAllFiloKretoTeam() async -> ApiResult<[UserDto]> {
        return await safeApiCall { try await self.accountApi.getAllFiloKretoTeam() }
    }

    func getAllManagerAndAdminUsers() async -> ApiResult<[UserDto]> {
        return await safeApiCall { try await self.accountApi.getAllManagerAndAdminUsers() }
    }

    func addUsersToFiloKretoTeam(userIds: [String]) async -> ApiResult<Bool> {
        return await safeApiCall { try await self.accountApi.addUsersToFiloKretoTeam(userIds: userIds) }
    }

    func removeUsersFromFiloKretoTeam(userIds: [String]) async -> ApiResult<Bool> {
        return await safeApiCall { try await self.accountApi.removeUsersFromFiloKretoTeam(userIds: userIds) }
    }

    func getMainMenuVisibility(user: UserDto) async -> ApiResult<MainMenuDto> {
        return await safeApiCall { try await self.accountApi.getMainMenuVisibility(user: user) }
    }
}
