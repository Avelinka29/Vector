import SwiftUI
import UIKit
import UserNotifications

struct NotificationSettingsView: View {
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(statusTitle)
                        .foregroundStyle(statusColor)
                } label: {
                    Label("Push-уведомления", systemImage: "bell.badge")
                }

                if status == .denied {
                    Button("Открыть настройки") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                } else if status == .notDetermined {
                    Button("Разрешить уведомления") {
                        Task { await requestPermission() }
                    }
                    .disabled(isRequesting)
                }
            } footer: {
                Text("Vector будет сообщать о важных изменениях в заявлениях. Разрешение можно отключить в настройках iPhone.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStatus() }
    }

    private var statusTitle: String {
        switch status {
        case .authorized: "Разрешены"
        case .provisional, .ephemeral: "Разрешены временно"
        case .denied: "Запрещены"
        case .notDetermined: "Не настроены"
        @unknown default: "Неизвестно"
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .red
        default: .secondary
        }
    }

    @MainActor
    private func refreshStatus() async {
        status = await NotificationService.shared.authorizationStatus()
    }

    @MainActor
    private func requestPermission() async {
        isRequesting = true
        defer { isRequesting = false }

        do {
            _ = try await NotificationService.shared.requestAuthorization()
            errorMessage = nil
            await refreshStatus()
        } catch {
            errorMessage = "Не удалось запросить разрешение: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
