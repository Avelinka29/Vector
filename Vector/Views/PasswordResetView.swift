import SwiftUI

struct PasswordResetLink: Identifiable {
    let id = UUID()
    let token: String

    init?(url: URL) {
        guard url.scheme == "vector", url.host == "auth", url.path == "/reset-password",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let tokens = (components.queryItems ?? []).filter { $0.name == "token" }
        guard tokens.count == 1, let value = tokens.first?.value,
              value.count >= 20, value.count <= 1024 else { return nil }
        token = value
    }
}

nonisolated private struct PasswordResetBody: Encodable, Sendable {
    let token: String
    let newPassword: String
}

struct PasswordResetView: View {
    let link: PasswordResetLink?
    @State private var pastedLink = ""

    private var resetToken: String? {
        if let link { return link.token }
        guard let url = URL(string: pastedLink.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return PasswordResetLink(url: url)?.token
    }
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isSaving = false
    @State private var completed = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        (8...128).contains(password.unicodeScalars.count)
            && password == confirmation && resetToken != nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                if completed {
                    Section {
                        Label("Пароль изменён", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Теперь войдите в VECTOR с новым паролем.")
                        Button("Готово") { dismiss() }
                    }
                } else {
                    if link == nil {
                        Section("Ссылка из письма") {
                            TextField("Вставьте полную ссылку", text: $pastedLink)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                        }
                    }
                    Section {
                        SecureField("Новый пароль", text: $password)
                            .textContentType(.newPassword)
                        SecureField("Повторите пароль", text: $confirmation)
                            .textContentType(.newPassword)
                    } footer: {
                        Text("От 8 до 128 символов. Ссылка действует 30 минут и используется один раз.")
                    }
                    if !confirmation.isEmpty && password != confirmation {
                        Text("Пароли не совпадают.")
                            .foregroundStyle(.red)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                    Section {
                        Button("Сохранить новый пароль") {
                            Task { await save() }
                        }
                        .disabled(!canSave)
                        if isSaving { ProgressView("Сохранение…") }
                    }
                }
            }
            .navigationTitle("Новый пароль")
            .toolbar {
                if !completed {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { dismiss() }
                            .disabled(isSaving)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() async {
        guard canSave, let token = resetToken else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let _: BackendMessageResponse = try await BackendAPIClient.shared.request(
                "/api/v1/auth/password/reset/confirm",
                method: "POST",
                body: PasswordResetBody(token: token, newPassword: password)
            )
            password = ""
            confirmation = ""
            completed = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
