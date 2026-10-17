import FirebaseAuth
import Foundation

@MainActor
protocol AuthenticationService {
    func restoreUser() async throws -> AuthenticatedUser?
    func signIn(email: String, password: String) async throws -> AuthenticatedUser
    func register(email: String, password: String) async throws -> AuthenticatedUser
    func signOut() throws
    func sendPasswordReset(email: String) async throws
}

enum AuthenticationError: LocalizedError {
    case missingEmail
    case weakPassword
    case invalidCredentials
    case unavailable

    var errorDescription: String? {
        switch self {
        case .missingEmail:
            "Введите корректный email."
        case .weakPassword:
            "Пароль должен содержать не менее 6 символов."
        case .invalidCredentials:
            "Неверный email или пароль."
        case .unavailable:
            "Не удалось выполнить авторизацию. Попробуйте ещё раз."
        }
    }
}

@MainActor
final class FirebaseAuthenticationService: AuthenticationService {
    func restoreUser() async throws -> AuthenticatedUser? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await authenticatedUser(from: user, forceRefresh: false)
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedUser {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return try await authenticatedUser(from: result.user, forceRefresh: true)
        } catch {
            throw map(error)
        }
    }

    func register(email: String, password: String) async throws -> AuthenticatedUser {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return try await authenticatedUser(from: result.user, forceRefresh: true)
        } catch {
            throw map(error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw map(error)
        }
    }

    private func authenticatedUser(
        from user: FirebaseAuth.User,
        forceRefresh: Bool
    ) async throws -> AuthenticatedUser {
        let token = try await user.getIDTokenResult(forcingRefresh: forceRefresh)
        let isAdmin = token.claims["admin"] as? Bool == true

        return AuthenticatedUser(
            id: user.uid,
            email: user.email ?? "",
            role: isAdmin ? .admin : .applicant
        )
    }

    private func map(_ error: Error) -> Error {
        let code = AuthErrorCode(rawValue: (error as NSError).code)

        switch code {
        case .invalidEmail:
            return AuthenticationError.missingEmail
        case .weakPassword:
            return AuthenticationError.weakPassword
        case .wrongPassword, .userNotFound, .invalidCredential:
            return AuthenticationError.invalidCredentials
        default:
            return error
        }
    }
}
