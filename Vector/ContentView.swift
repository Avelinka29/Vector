//
//  ContentView.swift
//  Vector
//
//  Created by Avelina Maksimchik on 06.08.2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PreferenceKeys.appTheme) private var storedTheme = AppTheme.system.rawValue
    @AppStorage(PreferenceKeys.biometricLockEnabled) private var biometricLockEnabled = false

    @State private var session = AppSession()
    @State private var isShowingSplash = true
    @State private var startupCompleted = false
    @State private var isBiometricallyUnlocked = false
    @State private var biometricError: String?

    private let biometrics = BiometricAuthenticationService()

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: storedTheme) ?? .system
    }

    private var requiresBiometricUnlock: Bool {
        biometricLockEnabled && session.isAuthenticated && !isBiometricallyUnlocked
    }

    var body: some View {
        ZStack {
            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
            } else if requiresBiometricUnlock {
                BiometricLockView(
                    errorMessage: biometricError,
                    onUnlock: {
                        Task { await unlockWithBiometrics() }
                    },
                    onUsePassword: usePasswordInstead
                )
                .transition(.opacity)
            } else {
                destination
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .task {
            guard !startupCompleted else { return }
            startupCompleted = true

            async let minimumSplash: Void = Task.sleep(for: .milliseconds(800))
            await session.restore()
            try? await minimumSplash

            if biometricLockEnabled && session.isAuthenticated {
                await unlockWithBiometrics()
            } else {
                isBiometricallyUnlocked = true
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                isShowingSplash = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active,
                  biometricLockEnabled,
                  session.isAuthenticated
            else { return }

            isBiometricallyUnlocked = false
            biometricError = nil
        }
        .onChange(of: biometricLockEnabled) { _, enabled in
            if !enabled {
                isBiometricallyUnlocked = true
                biometricError = nil
            }
        }
    }

    @ViewBuilder
    private var destination: some View {
        switch session.launchState {
        case .loading:
            ProgressView("Загрузка…")
                .tint(.systemBlue01)
        case .authentication:
            LoginView(session: session)
        case .registrationChoice(let user, _):
            RegistrationChoiceView(
                email: user.email,
                onFillNow: session.startProfileAfterRegistration,
                onFillLater: session.skipProfile
            )
        case .organizationApplication(let user):
            OrganizationApplicationView(
                email: user.email,
                initialType: user.role == .institution ? .institution : .employer,
                onSubmit: session.submitOrganizationApplication,
                onCancel: session.signOut
            )
        case .organization(let user, let organization):
            OrganizationRootView(
                user: user,
                organization: organization,
                onRefresh: session.refreshOrganization,
                onSignOut: session.signOut
            )
        case .applicant(let user, let account, let profile):
            ApplicantRootView(
                session: session,
                user: user,
                account: account,
                profile: profile
            )
        case .admin(let user):
            AdminDashboardView(user: user, onSignOut: session.signOut)
        }
    }

    @MainActor
    private func unlockWithBiometrics() async {
        biometricError = nil
        do {
            try await biometrics.authenticate()
            withAnimation(.easeInOut(duration: 0.2)) {
                isBiometricallyUnlocked = true
            }
        } catch {
            biometricError = error.localizedDescription
        }
    }

    private func usePasswordInstead() {
        session.signOut()
        isBiometricallyUnlocked = true
        biometricError = nil
    }
}

#Preview {
    ContentView()
}
