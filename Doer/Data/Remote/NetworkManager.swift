import Foundation
import Alamofire

class NetworkManager {
    static let shared = NetworkManager()

    let baseURL = "https://doerapi.doer.nz/api/"

    let session: Session

    private init() {
        let interceptor = AuthInterceptor()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30

        session = Session(
            configuration: configuration,
            interceptor: interceptor
        )
    }

    // MARK: - JSON Decoder
    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    // MARK: - GET Request
    func get<T: Decodable>(_ endpoint: String, parameters: [String: Any]? = nil) async throws -> T {
        print("[NET] GET \(endpoint) params: \(parameters ?? [:])")
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .get,
                parameters: parameters,
                encoding: URLEncoding.default
            )
            .validate()
            .responseData { response in
                let statusCode = response.response?.statusCode ?? 0
                print("[NET] GET \(endpoint) status: \(statusCode)")
                switch response.result {
                case .success(let data):
                    print("[NET] GET \(endpoint) response size: \(data.count)")
                    if endpoint.contains("GetFilesByShiftId") || endpoint.contains("GetFiles") {
                        if let raw = String(data: data, encoding: .utf8) {
                            print("[NET] RAW FILES RESPONSE: \(raw.prefix(1000))")
                        }
                    }
                    do {
                        let value = try Self.jsonDecoder.decode(T.self, from: data)
                        continuation.resume(returning: value)
                    } catch {
                        print("[NET] GET \(endpoint) decode error: \(error)")
                        if let errorString = String(data: data, encoding: .utf8) {
                            let cleanError = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            continuation.resume(throwing: NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: cleanError]))
                        } else {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    print("[NET] GET \(endpoint) error: \(error)")
                    if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                        let cleanError = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        continuation.resume(throwing: NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: cleanError]))
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - POST Request (JSON body)
    func post<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        print("[NET] POST \(endpoint)")
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .post,
                parameters: body,
                encoder: JSONParameterEncoder(encoder: Self.jsonEncoder)
            )
            .validate()
            .responseData { response in
                let statusCode = response.response?.statusCode ?? 0
                print("[NET] POST \(endpoint) status: \(statusCode)")
                switch response.result {
                case .success(let data):
                    print("[NET] POST \(endpoint) response size: \(data.count)")
                    do {
                        let value = try Self.jsonDecoder.decode(T.self, from: data)
                        continuation.resume(returning: value)
                    } catch {
                        print("[NET] POST \(endpoint) decode error: \(error)")
                        if let errorString = String(data: data, encoding: .utf8) {
                            print("[NET] POST \(endpoint) raw response: \(String(errorString.prefix(300)))")
                            let cleanError = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            continuation.resume(throwing: NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: cleanError]))
                        } else {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    print("[NET] POST \(endpoint) error: \(error)")
                    if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                        let cleanError = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        continuation.resume(throwing: NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: cleanError]))
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - PUT Request
    func put<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        print("[NET] PUT \(endpoint)")
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .put,
                parameters: body,
                encoder: JSONParameterEncoder(encoder: Self.jsonEncoder)
            )
            .validate()
            .responseData { response in
                let statusCode = response.response?.statusCode ?? 0
                print("[NET] PUT \(endpoint) status: \(statusCode)")
                switch response.result {
                case .success(let data):
                    do {
                        let value = try Self.jsonDecoder.decode(T.self, from: data)
                        continuation.resume(returning: value)
                    } catch {
                        if let errorString = String(data: data, encoding: .utf8) {
                            let cleanError = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            continuation.resume(throwing: NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: cleanError]))
                        } else {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                        let cleanError = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        continuation.resume(throwing: NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: cleanError]))
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - POST Request returning raw string response
    func postRaw<B: Encodable>(_ endpoint: String, body: B) async throws -> (String, Int) {
        print("[NET] POST-RAW \(endpoint)")
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .post,
                parameters: body,
                encoder: JSONParameterEncoder(encoder: Self.jsonEncoder)
            )
            .responseString { response in
                let statusCode = response.response?.statusCode ?? 0
                print("[NET] POST-RAW \(endpoint) status: \(statusCode)")
                switch response.result {
                case .success(let value):
                    print("[NET] POST-RAW \(endpoint) response length: \(value.count)")
                    continuation.resume(returning: (value, statusCode))
                case .failure(let error):
                    print("[NET] POST-RAW \(endpoint) error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - GET Request returning Bool
    func getBool(_ endpoint: String, parameters: [String: Any]? = nil) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .get,
                parameters: parameters,
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

    // MARK: - GET Request returning Int
    func getInt(_ endpoint: String, parameters: [String: Any]? = nil) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .get,
                parameters: parameters,
                encoding: URLEncoding.default
            )
            .validate()
            .responseDecodable(of: Int.self) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - GET Request returning String
    func getString(_ endpoint: String, parameters: [String: Any]? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .get,
                parameters: parameters,
                encoding: URLEncoding.default
            )
            .validate()
            .responseString { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - POST Request returning Bool
    func postBool<B: Encodable>(_ endpoint: String, body: B) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .post,
                parameters: body,
                encoder: JSONParameterEncoder(encoder: Self.jsonEncoder)
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

    // MARK: - POST Request returning String
    func postString<B: Encodable>(_ endpoint: String, body: B) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .post,
                parameters: body,
                encoder: JSONParameterEncoder(encoder: NetworkManager.jsonEncoder)
            )
            .validate()
            .responseString { response in
                let statusCode = response.response?.statusCode ?? 0
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    // Surface the HTTP status code as NSError.code so callers can detect
                    // specific failures like 404 (e.g. shift deleted on the server).
                    let body = response.data.flatMap { String(data: $0, encoding: .utf8) }?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? error.localizedDescription
                    continuation.resume(throwing: NSError(domain: "", code: statusCode,
                        userInfo: [NSLocalizedDescriptionKey: body]))
                }
            }
        }
    }

    func postString(_ endpoint: String, parameters: [String: Any]? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                baseURL + endpoint,
                method: .post,
                parameters: parameters,
                encoding: URLEncoding.default
            )
            .validate()
            .responseString { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Multipart Upload
    func upload<T: Decodable>(
        _ endpoint: String,
        fields: [String: String],
        files: [(data: Data, name: String, fileName: String, mimeType: String)]
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { multipartFormData in
                    for (key, value) in fields {
                        if let data = value.data(using: .utf8) {
                            if key == "request" {
                                multipartFormData.append(data, withName: key, mimeType: "application/json")
                            } else {
                                multipartFormData.append(data, withName: key)
                            }
                        }
                    }
                    for file in files {
                        multipartFormData.append(file.data, withName: file.name, fileName: file.fileName, mimeType: file.mimeType)
                    }
                },
                to: baseURL + endpoint,
                method: .post
            )
            .validate()
            .responseDecodable(of: T.self, decoder: Self.jsonDecoder) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                        let cleanError = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        continuation.resume(throwing: NSError(domain: "", code: response.response?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: cleanError]))
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Helper
    static func getMimeType(_ fileName: String) -> String {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") { return "image/jpeg" }
        if lower.hasSuffix(".png") { return "image/png" }
        if lower.hasSuffix(".pdf") { return "application/pdf" }
        return "application/octet-stream"
    }
}
