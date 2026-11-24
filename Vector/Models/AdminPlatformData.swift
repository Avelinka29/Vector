import Foundation

nonisolated struct AdminPlatformOverview: Decodable, Sendable {
    let users: Int
    let institutions: Int
    let companies: Int
    let pending: Int
}

nonisolated struct AdminParticipant: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let email: String
    let status: String
    let emailVerified: Bool

    var statusTitle: String {
        if !emailVerified { return "Ожидает подтверждения email" }
        switch status {
        case "active": return "Активен"
        case "pending": return "Ожидает проверки"
        case "needs_clarification": return "Нужно уточнение"
        case "rejected": return "Отклонён"
        case "blocked": return "Заблокирован"
        default: return status
        }
    }
}

nonisolated struct AdminParticipantsPage: Decodable, Sendable {
    let items: [AdminParticipant]
    let hasMore: Bool
}
