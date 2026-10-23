import Foundation
import Security

nonisolated enum BackendAPIError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case server(message: String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Не удалось настроить соединение с сервером."
        case .invalidResponse:
            "Сервер вернул некорректный ответ."
        case .server(let message):
            message
        case .unauthorized:
            "Сессия завершена. Войдите снова."
        }
    }
}

nonisolated struct BackendUserDTO: Codable, Sendable {
    let id: String
    let email: String
    let fullName: String
    let role: String
    let status: String
    let emailVerified: Bool
}

nonisolated struct BackendTokenResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: BackendUserDTO
}

nonisolated struct BackendMessageResponse: Codable, Sendable {
    let message: String
    let debugToken: String?
}

nonisolated private struct BackendErrorResponse: Codable, Sendable {
    let detail: String
}

nonisolated struct EmptyResponse: Decodable, Sendable {}

nonisolated final class BackendTokenStore: @unchecked Sendable {
    private let service = "by.vector.backend"
    private let accessAccount = "access-token"
    private let refreshAccount = "refresh-token"

    var accessToken: String? { read(account: accessAccount) }
    var refreshToken: String? { read(account: refreshAccount) }

    func save(accessToken: String, refreshToken: String) throws {
        try write(accessToken, account: accessAccount)
        try write(refreshToken, account: refreshAccount)
    }

    func clear() {
        delete(account: accessAccount)
        delete(account: refreshAccount)
    }

    private func write(_ value: String, account: String) throws {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(value.utf8)
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw BackendAPIError.invalidConfiguration
        }
    }

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

actor BackendAPIClient {
    static let shared = BackendAPIClient()

    private let session: URLSession
    private let tokenStore: BackendTokenStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let baseURL: URL

    init(
        session: URLSession? = nil,
        tokenStore: BackendTokenStore = BackendTokenStore()
    ) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 12
            configuration.timeoutIntervalForResource = 20
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
        self.tokenStore = tokenStore
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }
            let standard = ISO8601DateFormatter()
            if let date = standard.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Некорректная дата сервера"
            )
        }
        self.decoder = decoder

        let configured = Bundle.main.object(forInfoDictionaryKey: "VECTOR_API_BASE_URL") as? String
        self.baseURL = URL(string: configured ?? "http://127.0.0.1:8000")
            ?? URL(fileURLWithPath: "/")
    }

    func saveTokens(_ response: BackendTokenResponse) throws {
        try tokenStore.save(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
    }

    func clearTokens() {
        tokenStore.clear()
    }

    func hasRefreshToken() -> Bool {
        tokenStore.refreshToken != nil
    }

    func request<Response: Decodable & Sendable, Body: Encodable & Sendable>(
        _ path: String,
        method: String = "GET",
        body: Body? = Optional<String>.none,
        queryItems: [URLQueryItem] = [],
        authorized: Bool = false,
        retryAfterRefresh: Bool = true
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw BackendAPIError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try encoder.encode(body)
        }
        if authorized, let accessToken = tokenStore.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw BackendAPIError.server(
                    message: "Сервер не ответил вовремя. Проверьте, что он запущен и доступен в текущей сети."
                )
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                throw BackendAPIError.server(
                    message: "Не удалось подключиться к серверу. Проверьте Wi-Fi, VPN и адрес сервера."
                )
            default:
                throw error
            }
        }
        guard let http = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }
        if http.statusCode == 401, authorized, retryAfterRefresh {
            try await refreshTokens()
            return try await self.request(
                path,
                method: method,
                body: body,
                queryItems: queryItems,
                authorized: true,
                retryAfterRefresh: false
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            if let serverError = try? decoder.decode(BackendErrorResponse.self, from: data) {
                throw BackendAPIError.server(message: serverError.detail)
            }
            throw BackendAPIError.invalidResponse
        }
        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func refreshTokens() async throws {
        guard let refreshToken = tokenStore.refreshToken else {
            throw BackendAPIError.unauthorized
        }
        struct RefreshBody: Encodable, Sendable { let refreshToken: String }
        let response: BackendTokenResponse = try await request(
            "/api/v1/auth/refresh",
            method: "POST",
            body: RefreshBody(refreshToken: refreshToken)
        )
        try saveTokens(response)
    }
}

nonisolated struct BackendProfileEnvelope: Codable, @unchecked Sendable {
    let schemaVersion: Int
    let completionPercentage: Int
    let currentStep: Int
    let data: ApplicantProfile
    let updatedAt: Date?

    @MainActor
    init(profile: ApplicantProfile, currentStep: Int = 1) {
        self.schemaVersion = 1
        self.completionPercentage = profile.completionPercentage
        self.currentStep = currentStep
        self.data = profile
        self.updatedAt = nil
    }
}
