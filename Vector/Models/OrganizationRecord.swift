import Foundation

nonisolated enum OrganizationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case employer
    case institution

    var id: String { rawValue }

    var title: String {
        switch self {
        case .employer: "Работодатель"
        case .institution: "Учебное заведение"
        }
    }

    var icon: String {
        switch self {
        case .employer: "briefcase"
        case .institution: "building.columns"
        }
    }
}

nonisolated enum OrganizationVerificationStatus: String, Codable, Sendable {
    case pending
    case active
    case needsClarification = "needs_clarification"
    case rejected

    var title: String {
        switch self {
        case .pending: "Заявка на проверке"
        case .active: "Организация подтверждена"
        case .needsClarification: "Нужно уточнить данные"
        case .rejected: "Заявка отклонена"
        }
    }
}

nonisolated struct OrganizationRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let type: OrganizationType
    let name: String
    let legalName: String
    let taxId: String
    let city: String
    let website: String
    let description: String
    let status: OrganizationVerificationStatus
    let createdById: UUID
}

nonisolated struct OrganizationApplicationDraft: Sendable {
    var type: OrganizationType = .employer
    var name = ""
    var legalName = ""
    var taxId = ""
    var city = ""
    var website = ""
    var description = ""
}
