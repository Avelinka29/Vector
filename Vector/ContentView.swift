//
//  ContentView.swift
//  Vector
//
//  Created by Avelina Maksimchik on 06.08.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var session = AppSession()
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                destination
                    .transition(.opacity)
            }
        }
        .task {
            guard isShowingSplash else { return }

            async let restoreSession: Void = session.restore()
            try? await Task.sleep(for: .seconds(5.8))
            await restoreSession

            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                isShowingSplash = false
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
}

#Preview {
    ContentView()
}
