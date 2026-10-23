import SwiftUI

struct RegistrationChoiceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAppear = false
    let email: String
    let onFillNow: () -> Void
    let onFillLater: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 68))
                .foregroundStyle(.systemBlue01)
                .scaleEffect(didAppear ? 1 : 0.7)
                .opacity(didAppear ? 1 : 0)

            VStack(spacing: 10) {
                Text("Аккаунт создан")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.systemDarkBlue)
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Заполните профиль сейчас или перейдите в приложение и вернитесь к анкете позже.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Button("Заполнить профиль сейчас", action: onFillNow)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))

                Button("Заполнить позже", action: onFillLater)
                    .font(.headline)
                    .foregroundStyle(.systemBlue01)
                    .frame(maxWidth: .infinity, minHeight: 52)

            }

            Spacer()
        }
        .padding(24)
        .background(.systemWhite)
        .sensoryFeedback(.success, trigger: didAppear)
        .onAppear {
            if reduceMotion {
                didAppear = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    didAppear = true
                }
            }
        }
    }
}

struct ApplicantRootView: View {
    let session: AppSession
    let user: AuthenticatedUser
    let account: AppUser
    let profile: ApplicantProfile?

    @State private var showProfileEditor: Bool
    @State private var currentProfile: ApplicantProfile?
    @State private var isLoadingProfile = false
    @State private var profileLoadError: String?
    @State private var profileEditorStartStep: Int

    init(
        session: AppSession,
        user: AuthenticatedUser,
        account: AppUser,
        profile: ApplicantProfile?
    ) {
        self.session = session
        self.user = user
        self.account = account
        self.profile = profile
        _currentProfile = State(initialValue: profile)
        _showProfileEditor = State(
            initialValue: account.profileStatus == .inProgress
        )
        _profileEditorStartStep = State(initialValue: account.currentProfileStep)
    }

    var body: some View {
        MainTabView(
            userID: user.id,
            profile: currentProfile,
            profileStatus: account.profileStatus,
            onEditProfile: openProfileEditor,
            onEditDocuments: { openProfileEditor(startingAt: 7) },
            onSignOut: { session.signOut() },
            onDeleteAccount: { password in
                try await session.deleteAccount(userID: user.id, password: password)
            }
        )
        .overlay {
            if isLoadingProfile {
                ProgressView("Загрузка профиля…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .fullScreenCover(isPresented: $showProfileEditor) {
            ProfileEditorContainer(
                session: session,
                user: user,
                account: account,
                profile: currentProfile,
                startingStep: profileEditorStartStep,
                onProfileSaved: { savedProfile in
                    currentProfile = savedProfile
                },
                onClose: { showProfileEditor = false }
            )
        }
        .alert("Не удалось загрузить профиль", isPresented: profileLoadErrorBinding) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(profileLoadError ?? "Неизвестная ошибка.")
        }
    }

    private var profileLoadErrorBinding: Binding<Bool> {
        Binding(
            get: { profileLoadError != nil },
            set: { if !$0 { profileLoadError = nil } }
        )
    }

    private func openProfileEditor() {
        openProfileEditor(startingAt: account.currentProfileStep)
    }

    private func openProfileEditor(startingAt step: Int) {
        guard !isLoadingProfile else { return }

        Task {
            isLoadingProfile = true
            defer { isLoadingProfile = false }

            do {
                currentProfile = try await session.loadProfile(for: user.id)
                profileEditorStartStep = step
                showProfileEditor = true
            } catch {
                profileLoadError = error.localizedDescription
            }
        }
    }
}

struct ProfileEditorContainer: View {
    let session: AppSession
    let onProfileSaved: (ApplicantProfile) -> Void
    let onClose: () -> Void
    @State private var model: RegistrationViewModel

    init(
        session: AppSession,
        user: AuthenticatedUser,
        account: AppUser,
        profile: ApplicantProfile?,
        startingStep: Int,
        onProfileSaved: @escaping (ApplicantProfile) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.session = session
        self.onProfileSaved = onProfileSaved
        self.onClose = onClose

        var initialProfile = profile ?? ApplicantProfile()
        if initialProfile.contact.email.isEmpty {
            initialProfile.contact.email = user.email
        }

        _model = State(
            initialValue: RegistrationViewModel(
                profile: initialProfile,
                currentStep: startingStep,
                repository: session.profileRepository(for: user.id),
                accountRepository: session.accountRepository(),
                userID: user.id
            )
        )
    }

    var body: some View {
        NavigationStack {
            CreateProfileView(model: model) {
                session.profileDidSave(model.profile)
                onProfileSaved(model.profile)
                onClose()
            }
            .toolbar {
                if !model.isComplete {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть", action: onClose)
                    }
                }
            }
        }
    }
}
