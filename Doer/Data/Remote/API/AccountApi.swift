import Foundation
import Alamofire

class AccountApi {
    private let network = NetworkManager.shared

    func authenticate(body: LoginRequestDto) async throws -> (String, Int) {
        return try await network.postRaw("Account/Login", body: body)
    }

    func logout(userId: String) async throws -> UserDto {
        return try await network.get("Account/Logout", parameters: ["userId": userId])
    }

    func generateOtp(email: String) async throws -> UserDto {
        return try await network.get("Account/GenerateOtp", parameters: ["emailId": email])
    }

    func forgotPassword(otp: String, email: String, password: String) async throws -> Bool {
        return try await network.getBool("Account/ForgetPassword", parameters: [
            "otp": otp, "emailId": email, "password": password
        ])
    }

    func checkEmailExists(email: String) async throws -> Bool {
        return try await network.getBool("Account/emailexists", parameters: ["email": email])
    }

    func contactDetails(contactus: ContactusDto) async throws -> Bool {
        return try await network.postBool("Account/ContactTeam", body: contactus)
    }

    func registerContractor(
        fields: [String: String],
        documents: [(data: Data, name: String, fileName: String, mimeType: String)]
    ) async throws -> (String, Int) {
        return try await withCheckedThrowingContinuation { continuation in
            network.session.upload(
                multipartFormData: { multipartFormData in
                    for (key, value) in fields {
                        if let data = value.data(using: .utf8) {
                            multipartFormData.append(data, withName: key)
                        }
                    }
                    for doc in documents {
                        multipartFormData.append(doc.data, withName: doc.name, fileName: doc.fileName, mimeType: doc.mimeType)
                    }
                },
                to: NetworkManager.shared.baseURL + "Account/Register",
                method: .post
            )
            .responseString { response in
                let statusCode = response.response?.statusCode ?? 0
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: (value, statusCode))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func registerManager(registerUser: RegisterUserWithoutDocumentDto) async throws -> (String, Int) {
        return try await network.postRaw("Account/RegisterManager", body: registerUser)
    }

    func registerCustomer(user: UserDto) async throws -> UserDto {
        return try await network.post("Account/RegisterCustomer", body: user)
    }

    func getUser(id: String) async throws -> UserDto {
        return try await network.get("User/GetUserById", parameters: ["id": id])
    }

    func updateProfile(
        fields: [String: String],
        documents: [(data: Data, name: String, fileName: String, mimeType: String)]
    ) async throws -> UserDto {
        return try await network.upload("User/UpdateUserWithDocument", fields: fields, files: documents)
    }

    func deleteDocument(id: Int) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            network.session.request(
                network.baseURL + "User/DeleteDocumentById",
                method: .post,
                parameters: ["id": id],
                encoding: URLEncoding.default
            )
            .validate()
            .responseDecodable(of: Bool.self) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteUserAccount(userId: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            network.session.request(
                network.baseURL + "User/DeleteUserAccount",
                method: .post,
                parameters: ["id": userId],
                encoding: URLEncoding.default
            )
            .validate()
            .responseDecodable(of: Bool.self) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getAllContractors() async throws -> [UserDto] {
        return try await network.get("User/GetCaregiverUsers")
    }

    func getAllManagers() async throws -> [UserDto] {
        return try await network.get("User/GetManagerUsers")
    }

    func searchContractorsBySkillsAndLocation(
        latitude: Double, longitude: Double, searchSkills: String, searchName: String
    ) async throws -> [UserDto] {
        return try await network.get("User/SearchCaregiverUsersBySkillsAndLocation", parameters: [
            "latitude": latitude, "longitude": longitude, "skill": searchSkills, "name": searchName
        ])
    }

    func getAllUsersWithAdmin() async throws -> [UserDto] {
        return try await network.get("User/GetAllUsersWithAdmin")
    }

    func getAllFiloKretoTeam() async throws -> [UserDto] {
        return try await network.get("User/getAllFiloKretoTeam")
    }

    func getAllManagerAndAdminUsers() async throws -> [UserDto] {
        return try await network.get("User/GetAllManagerAndAdminUsers")
    }

    func addUsersToFiloKretoTeam(userIds: [String]) async throws -> Bool {
        return try await network.postBool("user/addToFiloKretoTeam", body: userIds)
    }

    func removeUsersFromFiloKretoTeam(userIds: [String]) async throws -> Bool {
        return try await network.postBool("user/removeFromFiloKretoTeam", body: userIds)
    }

    func getMainMenuVisibility(user: UserDto) async throws -> MainMenuDto {
        return try await network.post("AccountDetails/GetMainMenuVisibility", body: user)
    }
}
