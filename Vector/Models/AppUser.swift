import Foundation

enum AppRole: String, Codable, Equatable {
    case applicant
    case employer
    case institution
    case moderator
    case admin
}

enum ProfileStatus: String, Codable, Equatable {
    case notStarted
    case inProgress
    case complete
}

struct AuthenticatedUser: Equatable {
    let id: String
    let email: String
    let role: AppRole
}

struct AppUser: Codable, Equatable, Identifiable {
    let id: String
    let email: String
    var profileStatus: ProfileStatus
    var currentProfileStep: Int
    var createdAt: Date?
    var updatedAt: Date?
}
