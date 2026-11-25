import Foundation
import Security
import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

nonisolated private struct DeviceTokenBody: Encodable, Sendable {
    let token: String
    let platform: String
}

nonisolated private struct DeviceTokenResponse: Decodable, Sendable {
    let token: String
    let platform: String
}

protocol MessagingTokenStore: Sendable {
    func save(_ token: String) throws
    func load() throws -> String?
    func delete() throws
}

struct KeychainMessagingTokenStore: MessagingTokenStore {
    private let service = "by.vector.notifications"
    private let account = "fcm-token"

    func save(_ token: String) throws {
        let data = Data(token.utf8)
        let query = baseQuery
        let status = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )

        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw TokenStoreError.keychain(addStatus)
            }
        } else if status != errSecSuccess {
            throw TokenStoreError.keychain(status)
        }
    }

    func load() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw TokenStoreError.keychain(status)
        }
        return String(data: data, encoding: .utf8)
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum TokenStoreError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            "Не удалось сохранить токен уведомлений (код \(status))."
        }
    }
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let tokenStore: any MessagingTokenStore

    private(set) var lastErrorMessage: String?

    init(tokenStore: any MessagingTokenStore = KeychainMessagingTokenStore()) {
        self.tokenStore = tokenStore
        super.init()
    }

    func configure() {
        center.delegate = self

        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        Task {
            let status = await authorizationStatus()
            if [.authorized, .provisional, .ephemeral].contains(status) {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        let settings = await center.notificationSettings()
        let granted: Bool

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            granted = true
        case .notDetermined:
            granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        case .denied:
            granted = false
        @unknown default:
            granted = false
        }

        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    func registerAPNsToken(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        Task {
            do {
                let token = try await Messaging.messaging().token()
                store(token)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
        #endif
    }

    func didFailToRegister(error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    func syncTokenIfAvailable() async {
        do {
            guard await BackendAPIClient.shared.hasRefreshToken(),
                  let token = try tokenStore.load() else { return }
            let _: DeviceTokenResponse = try await BackendAPIClient.shared.request(
                "/api/v1/notifications/device-token",
                method: "PUT",
                body: DeviceTokenBody(token: token, platform: "ios"),
                authorized: true
            )
            lastErrorMessage = nil
        } catch BackendAPIError.unauthorized {
            // The token is retained in Keychain and will be synced after the next sign-in.
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func scheduleDeadlineReminders(for applications: [ApplicationRecord]) async {
        let status = await authorizationStatus()
        guard [.authorized, .provisional, .ephemeral].contains(status) else { return }

        let identifiers = applications.flatMap {
            ["deadline.\($0.id).3", "deadline.\($0.id).1"]
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for application in applications {
            guard let value = application.submissionDeadline,
                  let deadline = Self.deadlineDate(from: value) else { continue }
            for daysBefore in [3, 1] {
                guard let reminderDate = Calendar.current.date(
                    byAdding: .day,
                    value: -daysBefore,
                    to: deadline
                ), reminderDate > .now else { continue }

                let content = UNMutableNotificationContent()
                content.title = daysBefore == 1 ? "Срок уже завтра" : "Приближается срок заявления"
                content.body = "\(application.institutionName): проверьте документы до \(value)."
                content.sound = .default
                content.userInfo = ["application_id": application.id]

                var components = Calendar.current.dateComponents(
                    [.year, .month, .day],
                    from: reminderDate
                )
                components.hour = 10
                let request = UNNotificationRequest(
                    identifier: "deadline.\(application.id).\(daysBefore)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                do {
                    try await center.add(request)
                } catch {
                    lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    private func store(_ token: String) {
        do {
            try tokenStore.save(token)
            lastErrorMessage = nil
            Task { await syncTokenIfAvailable() }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private static func deadlineDate(from value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: 10
        ))
    }
}

#if canImport(FirebaseMessaging)
extension NotificationService: MessagingDelegate {
    nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else { return }
        Task { @MainActor in
            self.store(fcmToken)
        }
    }
}
#endif
