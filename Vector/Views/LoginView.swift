import SwiftUI

struct LoginView: View {
    let session: AppSession

    @State private var selectedTab = 0
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRegistrationRole: AppRole = .applicant
    @State private var isWorking = false
    @State private var isSendingPasswordReset = false
    @State private var passwordResetAlert: PasswordResetAlert?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LoginHeader(isRegistration: selectedTab == 1)
                    LoginModePicker(selectedTab: $selectedTab)

                    if selectedTab == 1 {
                        RegistrationRolePicker(selection: $selectedRegistrationRole)
                    }

                    VectorTextField(
                        icon: "envelope",
                        placeholder: "Email",
                        text: $email
                    )
                    .textInputAutocapitalization(.never)

                    VectorTextField(
                        icon: "lock",
                        placeholder: "Пароль",
                        isSecure: true,
                        text: $password
                    )

                    if let message = session.errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(message.contains("отправлено") ? .green : .red)
                    }

                    if selectedTab == 0 {
                        Button(isSendingPasswordReset ? "Отправляем…" : "Забыли пароль?") {
                            Task { await resetPassword() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.systemBlue01)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .disabled(isSendingPasswordReset)
                    }

                    VectorButton(
                        title: selectedTab == 0 ? "Войти" : "Создать аккаунт",
                        icon: "arrow.forward",
                        backgroundColor: .blue01,
                        isInfinity: true
                    ) {
                        Task { await submit() }
                    }
                    .disabled(isWorking || email.isEmpty || password.isEmpty)
                    .opacity(isWorking || email.isEmpty || password.isEmpty ? 0.6 : 1)

                    if isWorking {
                        ProgressView()
                            .tint(.systemBlue01)
                            .frame(maxWidth: .infinity)
                    }

                    LoginDivider()

                    SocialSignInSection(
                        isRegistration: selectedTab == 1,
                        onGoogle: { showUnavailableProvider("Google") },
                        onApple: { showUnavailableProvider("Apple") }
                    )

                    LoginAccountPrompt(
                        isRegistration: selectedTab == 1,
                        onSwitchMode: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = selectedTab == 0 ? 1 : 0
                            }
                        }
                    )

                    LoginInformationCard(isRegistration: selectedTab == 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.systemWhite)
            .alert(item: $passwordResetAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("Хорошо"))
                )
            }
        }
    }

    private func submit() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        if selectedTab == 0 {
            await session.signIn(email: email, password: password)
        } else {
            await session.register(
                email: email,
                password: password,
                role: selectedRegistrationRole
            )
        }
    }

    private func resetPassword() async {
        guard !isSendingPasswordReset else { return }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            passwordResetAlert = .error("Сначала введите email, указанный при регистрации.")
            return
        }

        isSendingPasswordReset = true
        defer { isSendingPasswordReset = false }

        do {
            try await session.sendPasswordReset(email: normalizedEmail)
            passwordResetAlert = .success(email: normalizedEmail)
        } catch {
            passwordResetAlert = .error(error.localizedDescription)
        }
    }

    private func showUnavailableProvider(_ provider: String) {
        session.errorMessage = "Вход через \(provider) временно недоступен."
    }
}

private struct RegistrationRolePicker: View {
    @Binding var selection: AppRole

    private let options = [
        RegistrationRoleOption(
            role: .applicant,
            title: "Абитуриент",
            subtitle: "Поступление и личный профиль",
            icon: "person"
        ),
        RegistrationRoleOption(
            role: .institution,
            title: "Учреждение образования",
            subtitle: "Программы и работа с абитуриентами",
            icon: "building.columns"
        ),
        RegistrationRoleOption(
            role: .employer,
            title: "Работодатель",
            subtitle: "Вакансии и поиск кандидатов",
            icon: "briefcase"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Кто вы?")
                .font(.headline)
                .foregroundStyle(.systemDarkBlue)

            ForEach(options) { option in
                Button {
                    selection = option.role
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.icon)
                            .font(.title3)
                            .frame(width: 28)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title)
                                .font(.body.weight(.semibold))
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(selection == option.role ? .white.opacity(0.8) : .secondary)
                        }

                        Spacer()

                        Image(systemName: selection == option.role ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(selection == option.role ? .white : .systemDarkBlue)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selection == option.role ? Color.systemBlue01 : Color.systemBlue01.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityValue(selection == option.role ? "Выбрано" : "Не выбрано")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selection)
    }
}

private struct RegistrationRoleOption: Identifiable {
    let role: AppRole
    let title: String
    let subtitle: String
    let icon: String

    var id: String { role.rawValue }
}

private struct PasswordResetAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func success(email: String) -> PasswordResetAlert {
        PasswordResetAlert(
            title: "Письмо отправлено",
            message: "Мы отправили ссылку для сброса пароля на \(email). Проверьте также папку «Спам»."
        )
    }

    static func error(_ message: String) -> PasswordResetAlert {
        PasswordResetAlert(title: "Не удалось отправить письмо", message: message)
    }
}

struct LoginHeader: View {
    let isRegistration: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isRegistration ? "Добро пожаловать в Vector" : "С возвращением")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.systemDarkBlue)
            Text("Единая цифровая платформа поступления")
                .font(.title3.weight(.medium))
                .foregroundStyle(.systemDarkBlue.opacity(0.5))
        }
        .padding(.top, 20)
    }
}

struct LoginModePicker: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 4) {
            LoginModeButton(title: "Вход", tag: 0, selectedTab: $selectedTab)
            LoginModeButton(title: "Регистрация", tag: 1, selectedTab: $selectedTab)
        }
        .padding(6)
        .background(.systemWhite, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .padding(.vertical, 10)
    }
}

struct LoginModeButton: View {
    let title: String
    let tag: Int
    @Binding var selectedTab: Int

    var body: some View {
        Button(title) {
            selectedTab = tag
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(selectedTab == tag ? .white : .systemGrey1)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
            selectedTab == tag ? Color.systemBlue01 : Color.clear,
            in: RoundedRectangle(cornerRadius: 15)
        )
    }
}

struct LoginDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.systemGrey1.opacity(0.45))
                .frame(height: 1)
            Text("ИЛИ")
                .font(.caption.weight(.bold))
                .foregroundStyle(.systemGrey1)
            Rectangle()
                .fill(.systemGrey1.opacity(0.45))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

struct SocialSignInSection: View {
    let isRegistration: Bool
    let onGoogle: () -> Void
    let onApple: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            SocialSignInButton(
                title: isRegistration ? "Зарегистрироваться через Google" : "Войти через Google",
                imageName: "Google",
                action: onGoogle
            )
            SocialSignInButton(
                title: isRegistration ? "Зарегистрироваться через Apple" : "Войти через Apple",
                imageName: "Apple",
                action: onApple
            )
        }
    }
}

struct SocialSignInButton: View {
    let title: LocalizedStringResource
    let imageName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if imageName == "Apple" {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.systemDarkBlue)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                } else {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }

                Spacer()

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                    .multilineTextAlignment(.center)

                Spacer()

                Color.clear
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.systemGrey1.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct LoginAccountPrompt: View {
    let isRegistration: Bool
    let onSwitchMode: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(isRegistration ? "Уже есть аккаунт?" : "Нет аккаунта?")
                .foregroundStyle(.systemGrey1)
            Button(
                isRegistration ? "Войти" : "Зарегистрироваться",
                action: onSwitchMode
            )
            .fontWeight(.semibold)
            .foregroundStyle(.systemBlue01)
        }
        .font(.body)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

struct LoginInformationCard: View {
    let isRegistration: Bool

    var body: some View {
        Label(
            isRegistration
                ? "Для учреждения или работодателя после регистрации потребуется заполнить заявку на проверку."
                : "Войдите в аккаунт абитуриента, организации или администратора.",
            systemImage: isRegistration ? "person.crop.circle.badge.plus" : "lock.shield"
        )
        .font(.subheadline)
        .foregroundStyle(.systemDarkBlue.opacity(0.7))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.systemBlue01.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    LoginView(session: AppSession())
}
