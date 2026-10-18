import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    enum LaunchState {
        case loading
        case authentication
        case registrationChoice(AuthenticatedUser, AppUser)
        case applicant(AuthenticatedUser, AppUser, ApplicantProfile?)
        case admin(AuthenticatedUser)
    }

    var launchState: LaunchState = .loading
    var errorMessage: String?

    private let authentication: any AuthenticationService
    private let accounts: any UserAccountRepository

    init(
        authentication: (any AuthenticationService)? = nil,
        accounts: (any UserAccountRepository)? = nil
    ) {
        self.authentication = authentication ?? FirebaseAuthenticationService()
        self.accounts = accounts ?? FirestoreUserAccountRepository()
    }

    func restore() async {
        launchState = .loading
        errorMessage = nil

        do {
            guard let user = try await authentication.restoreUser() else {
                launchState = .authentication
                return
            }
            await routeAuthenticatedUser(user)
        } catch {
            errorMessage = error.localizedDescription
            launchState = .authentication
        }
    }

    func signIn(email: String, password: String) async {
        launchState = .loading
        errorMessage = nil

        do {
            let user = try await authentication.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            await routeAuthenticatedUser(user)
        } catch {
            errorMessage = error.localizedDescription
            launchState = .authentication
        }
    }

    func register(email: String, password: String) async {
        launchState = .loading
        errorMessage = nil

        do {
            let user = try await authentication.register(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            let account = try await accounts.createApplicant(id: user.id, email: user.email)
            launchState = .registrationChoice(user, account)
        } catch {
            try? authentication.signOut()
            errorMessage = error.localizedDescription
            launchState = .authentication
        }
    }

    func skipProfile() {
        guard case .registrationChoice(let user, let account) = launchState else { return }
        launchState = .applicant(user, account, nil)
    }

    func startProfileAfterRegistration() {
        guard case .registrationChoice(let user, var account) = launchState else { return }
        account.profileStatus = .inProgress
        launchState = .applicant(user, account, nil)
    }

    func profileDidSave(_ profile: ApplicantProfile) {
        switch launchState {
        case .applicant(let user, var account, _):
            account.profileStatus = .complete
            account.currentProfileStep = RegistrationViewModel.totalSteps
            launchState = .applicant(user, account, profile)
        case .registrationChoice(let user, var account):
            account.profileStatus = .complete
            account.currentProfileStep = RegistrationViewModel.totalSteps
            launchState = .applicant(user, account, profile)
        default:
            break
        }
    }

    func signOut() {
        do {
            try authentication.signOut()
            errorMessage = nil
            launchState = .authentication
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await authentication.sendPasswordReset(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func profileRepository(for userID: String) -> any ProfileRepository {
        FirestoreProfileRepository(userID: userID)
    }

    func loadProfile(for userID: String) async throws -> ApplicantProfile? {
        try await profileRepository(for: userID).loadProfile()
    }

    func accountRepository() -> any UserAccountRepository {
        accounts
    }

    private func routeAuthenticatedUser(_ user: AuthenticatedUser) async {
        if user.role == .admin {
            launchState = .admin(user)
            return
        }

        do {
            let account: AppUser
            if let existing = try await accounts.load(id: user.id) {
                account = existing
            } else {
                account = try await accounts.createApplicant(id: user.id, email: user.email)
            }

            let profile = try await profileRepository(for: user.id).loadProfile()
            launchState = .applicant(user, account, profile)
        } catch {
            errorMessage = error.localizedDescription
            launchState = .authentication
        }
    }
}
