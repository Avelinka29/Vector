import Foundation

nonisolated private struct BackendLoginBody: Encodable, Sendable {
    let email: String
    let password: String
}

nonisolated private struct BackendRegisterBody: Encodable, Sendable {
    let email: String
    let password: String
    let fullName: String
    let role: AppRole
}

nonisolated private struct BackendEmailBody: Encodable, Sendable {
    let email: String
}

nonisolated private struct BackendPasswordBody: Encodable, Sendable {
    let password: String
}

@MainActor
final class BackendAuthenticationService: AuthenticationService {
    private let api = BackendAPIClient.shared
    private var currentEmail: String?
    private var reauthenticatedPassword: String?

    func restoreUser() async throws -> AuthenticatedUser? {
        guard await api.hasRefreshToken() else { return nil }
        do {
            let user: BackendUserDTO = try await api.request(
                "/api/v1/auth/me",
                authorized: true
            )
            currentEmail = user.email
            return authenticatedUser(from: user)
        } catch {
            await api.clearTokens()
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedUser {
        let response: BackendTokenResponse = try await api.request(
            "/api/v1/auth/login",
            method: "POST",
            body: BackendLoginBody(email: email, password: password)
        )
        try await api.saveTokens(response)
        currentEmail = response.user.email
        return authenticatedUser(from: response.user)
    }

    func register(email: String, password: String, role: AppRole) async throws -> AuthenticatedUser {
        let fallbackName = String(email.split(separator: "@").first ?? "Пользователь")
        let response: BackendTokenResponse = try await api.request(
            "/api/v1/auth/register",
            method: "POST",
            body: BackendRegisterBody(
                email: email,
                password: password,
                fullName: fallbackName,
                role: role
            )
        )
        try await api.saveTokens(response)
        currentEmail = response.user.email
        return authenticatedUser(from: response.user)
    }

    func signInWithGoogle(idToken: String, role: AppRole, registering: Bool) async throws -> AuthenticatedUser {
        nonisolated struct GoogleBody: Encodable, Sendable {
            let idToken: String
            let role: AppRole
        }
        let response: BackendTokenResponse = try await api.request(
            registering ? "/api/v1/auth/google/register" : "/api/v1/auth/google",
            method: "POST",
            body: GoogleBody(idToken: idToken, role: role)
        )
        try await api.saveTokens(response)
        currentEmail = response.user.email
        return authenticatedUser(from: response.user)
    }

    func signOut() throws {
        Task { await api.clearTokens() }
        currentEmail = nil
    }

    func sendPasswordReset(email: String) async throws {
        let _: BackendMessageResponse = try await api.request(
            "/api/v1/auth/password/reset/request",
            method: "POST",
            body: BackendEmailBody(email: email)
        )
    }

    func reauthenticate(password: String) async throws {
        guard let currentEmail else { throw AuthenticationError.unavailable }
        _ = try await signIn(email: currentEmail, password: password)
        reauthenticatedPassword = password
    }

    func deleteCurrentUser() async throws {
        guard let password = reauthenticatedPassword else {
            throw AuthenticationError.unavailable
        }
        defer { reauthenticatedPassword = nil }
        let _: EmptyResponse = try await api.request(
            "/api/v1/auth/account",
            method: "DELETE",
            body: BackendPasswordBody(password: password),
            authorized: true
        )
        await api.clearTokens()
    }

    private func authenticatedUser(from user: BackendUserDTO) -> AuthenticatedUser {
        AuthenticatedUser(
            id: user.id,
            email: user.email,
            role: AppRole(rawValue: user.role) ?? .applicant
        )
    }
}
