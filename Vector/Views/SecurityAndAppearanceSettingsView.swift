import SwiftUI

struct SecurityAndAppearanceSettingsView: View {
    @AppStorage(PreferenceKeys.appTheme) private var storedTheme = AppTheme.system.rawValue
    @AppStorage(PreferenceKeys.biometricLockEnabled) private var biometricLockEnabled = false

    @State private var isCheckingBiometrics = false
    @State private var errorMessage: String?

    private let biometrics = BiometricAuthenticationService()

    private var selectedTheme: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: storedTheme) ?? .system },
            set: { storedTheme = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Оформление") {
                Picker("Тема приложения", selection: selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                Text("Системная тема следует настройкам iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Безопасность") {
                Toggle(isOn: $biometricLockEnabled) {
                    Label("Разблокировка по Face ID", systemImage: "faceid")
                }
                .disabled(isCheckingBiometrics || !biometrics.isAvailable())
                .onChange(of: biometricLockEnabled) { _, isEnabled in
                    guard isEnabled else { return }
                    Task {
                        await verifyBiometricsBeforeEnabling()
                    }
                }

                if !biometrics.isAvailable() {
                    Text("На устройстве не настроены Face ID, Touch ID или код-пароль.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("После включения приложение будет запрашивать Face ID при новом запуске и после возврата из фона. Если распознавание не сработает, iPhone предложит код-пароль устройства. Пароль аккаунта не сохраняется.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Внешний вид и защита")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Не удалось включить биометрию", isPresented: errorBinding) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Повторите попытку.")
        }
    }

    @MainActor
    private func verifyBiometricsBeforeEnabling() async {
        isCheckingBiometrics = true
        defer { isCheckingBiometrics = false }

        do {
            try await biometrics.authenticate()
        } catch {
            biometricLockEnabled = false
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

struct BiometricLockView: View {
    let errorMessage: String?
    let onUnlock: () -> Void
    let onUsePassword: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 72))
                .foregroundStyle(.systemBlue01)

            VStack(spacing: 8) {
                Text("VECTOR заблокирован")
                    .font(.title.bold())
                    .foregroundStyle(.systemDarkBlue)
                Text("Подтвердите личность, чтобы продолжить.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Разблокировать", action: onUnlock)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))

            Button("Войти с паролем", action: onUsePassword)
                .font(.headline)
                .foregroundStyle(.systemBlue01)
                .frame(minHeight: 48)

            Spacer()
        }
        .padding(24)
        .background(.systemWhite)
    }
}
