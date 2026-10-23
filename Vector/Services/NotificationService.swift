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
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                Task { @MainActor in
                    self?.lastErrorMessage = error.localizedDescription
                }
                return
            }
            guard let token else { return }
            self?.store(token)
        }
        #endif
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
        #endif
    }

    func didFailToRegister(error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    func syncTokenIfAvailable() async {
        do {
            guard let token = try tokenStore.load() else { return }
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
        } catch {
            lastErrorMessage = error.localizedDescription
        }
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
