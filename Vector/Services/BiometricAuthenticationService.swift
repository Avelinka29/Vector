import Foundation
import LocalAuthentication

nonisolated enum BiometricAuthenticationError: LocalizedError {
    case unavailable
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "На устройстве не настроены Face ID, Touch ID или код-пароль."
        case .failed:
            "Не удалось подтвердить личность."
        }
    }
}

struct BiometricAuthenticationService: Sendable {
    func isAvailable() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func authenticate() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Отмена"
        context.localizedFallbackTitle = "Ввести код-пароль"

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: nil
        ) else {
            throw BiometricAuthenticationError.unavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Разблокируйте доступ к своему аккаунту"
            )
            guard success else {
                throw BiometricAuthenticationError.failed
            }
        } catch {
            throw error
        }
    }
}
