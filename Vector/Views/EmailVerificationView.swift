import SwiftUI

struct EmailVerificationLink: Identifiable {
    let id = UUID()
    let token: String

    init?(url: URL) {
        guard url.scheme == "vector", url.host == "auth", url.path == "/verify-email",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let tokens = (components.queryItems ?? []).filter { $0.name == "token" }
        guard tokens.count == 1, let value = tokens.first?.value,
              (20...1024).contains(value.count) else { return nil }
        token = value
    }
}

nonisolated private struct EmailVerificationBody: Encodable, Sendable {
    let token: String
}

struct EmailVerificationView: View {
    let link: EmailVerificationLink?
    @Environment(\.dismiss) private var dismiss
    @State private var pastedLink = ""
    @State private var isWorking = false
    @State private var completed = false
    @State private var errorMessage: String?

    private var token: String? {
        if let link { return link.token }
        guard let url = URL(string: pastedLink.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return EmailVerificationLink(url: url)?.token
    }

    var body: some View {
        NavigationStack {
            Form {
                if completed {
                    Label("Email подтверждён", systemImage: "checkmark.circle.fill")
                    Button("Готово") { dismiss() }
                } else {
                    if link == nil {
                        TextField("Полная ссылка из письма", text: $pastedLink)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    Text("Подтвердите адрес по ссылке из письма VECTOR. Ссылка действует 24 часа и используется один раз.")
                    Button("Подтвердить email") {
                        Task { await confirm() }
                    }
                    .disabled(token == nil || isWorking)
                    if isWorking { ProgressView() }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Подтверждение email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private func confirm() async {
        guard let token, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let _: BackendMessageResponse = try await BackendAPIClient.shared.request(
                "/api/v1/auth/email/verification/confirm", method: "POST",
                body: EmailVerificationBody(token: token)
            )
            completed = true
            pastedLink = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
