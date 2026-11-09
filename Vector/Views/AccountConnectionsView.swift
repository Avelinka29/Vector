import SwiftUI

nonisolated private struct GoogleLinkBody: Encodable, Sendable {
    let idToken: String
}

struct AccountConnectionsView: View {
    @State private var message: String?
    @State private var isWorking = false
    @State private var showsVerification = false

    var body: some View {
        Form {
            Section("Google") {
                Text("Привяжите Google с тем же email к текущему аккаунту VECTOR.")
                Button("Привязать Google") {
                    Task { await linkGoogle() }
                }
                .disabled(isWorking)
            }
            Section("Подтверждение email") {
                Button("Отправить письмо подтверждения") {
                    Task { await resendVerification() }
                }
                .disabled(isWorking)
                Button("Вставить ссылку из письма") {
                    showsVerification = true
                }
            }
            if isWorking { ProgressView() }
            if let message { Text(message) }
        }
        .navigationTitle("Вход и email")
        .sheet(isPresented: $showsVerification) {
            EmailVerificationView(link: nil)
        }
    }

    private func linkGoogle() async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let token = try await GoogleSignInService.idToken()
            let result: BackendMessageResponse = try await BackendAPIClient.shared.request(
                "/api/v1/auth/google/link", method: "POST",
                body: GoogleLinkBody(idToken: token), authorized: true
            )
            message = result.message
        } catch is CancellationError {
        } catch {
            message = error.localizedDescription
        }
    }

    private func resendVerification() async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let result: BackendMessageResponse = try await BackendAPIClient.shared.request(
                "/api/v1/auth/email/verification/request", method: "POST", authorized: true
            )
            message = result.message
        } catch {
            message = error.localizedDescription
        }
    }
}
