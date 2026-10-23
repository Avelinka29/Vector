import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    enum LaunchState {
        case loading
        case authentication
        case registrationChoice(AuthenticatedUser, AppUser)
        case organizationApplication(AuthenticatedUser)
        case organization(AuthenticatedUser, OrganizationRecord?)
        case applicant(AuthenticatedUser, AppUser, ApplicantProfile?)
        case admin(AuthenticatedUser)
    }

    var launchState: LaunchState = .loading
    var errorMessage: String?

    var isAuthenticated: Bool {
        switch launchState {
        case .loading, .authentication:
            false
        case .registrationChoice, .organizationApplication, .organization, .applicant, .admin:
            true
        }
    }

    private let authentication: any AuthenticationService
    private let accounts: any UserAccountRepository
    private let accountDeletion = AccountDeletionService()
    private let organizations = OrganizationService()

    init(
        authentication: (any AuthenticationService)? = nil,
        accounts: (any UserAccountRepository)? = nil
    ) {
        self.authentication = authentication ?? BackendAuthenticationService()
        self.accounts = accounts ?? BackendUserAccountRepository()
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

    func register(email: String, password: String, role: AppRole) async {
        launchState = .loading
        errorMessage = nil

        do {
            let user = try await authentication.register(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                role: role
            )
            Task {
                await NotificationService.shared.syncTokenIfAvailable()
            }

            switch user.role {
            case .applicant:
                let account = try await accounts.createApplicant(id: user.id, email: user.email)
                launchState = .registrationChoice(user, account)
            case .employer, .institution:
                launchState = .organizationApplication(user)
            case .moderator, .admin:
                throw AuthenticationError.unavailable
            }
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

    func startOrganizationApplication() {
        guard case .registrationChoice(let user, _) = launchState else { return }
        launchState = .organizationApplication(user)
    }

    func cancelOrganizationApplication() async {
        guard case .organizationApplication(let user) = launchState else { return }
        await routeAuthenticatedUser(user)
    }

    func submitOrganizationApplication(_ draft: OrganizationApplicationDraft) async throws {
        guard case .organizationApplication(let user) = launchState else { return }
        let organization = try await organizations.apply(draft)
        let role: AppRole = draft.type == .institution ? .institution : .employer
        let organizationUser = AuthenticatedUser(id: user.id, email: user.email, role: role)
        launchState = .organization(organizationUser, organization)
    }

    func refreshOrganization() async {
        guard case .organization(let user, _) = launchState else { return }
        do {
            let organization = try await organizations.loadMine()
            launchState = .organization(user, organization)
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func deleteAccount(userID: String, password: String) async throws {
        try await authentication.reauthenticate(password: password)
        if authentication is FirebaseAuthenticationService {
            try await accountDeletion.deleteData(userID: userID)
        }
        try await authentication.deleteCurrentUser()
        errorMessage = nil
        launchState = .authentication
    }

    func profileRepository(for userID: String) -> any ProfileRepository {
        BackendProfileRepository()
    }

    func loadProfile(for userID: String) async throws -> ApplicantProfile? {
        try await profileRepository(for: userID).loadProfile()
    }

    func accountRepository() -> any UserAccountRepository {
        accounts
    }

    private func routeAuthenticatedUser(_ user: AuthenticatedUser) async {
        Task {
            await NotificationService.shared.syncTokenIfAvailable()
        }

        if user.role == .admin || user.role == .moderator {
            launchState = .admin(user)
            return
        }

        if user.role == .employer || user.role == .institution {
            do {
                let organization = try await organizations.loadMine()
                launchState = .organization(user, organization)
            } catch {
                errorMessage = error.localizedDescription
                launchState = .authentication
            }
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
