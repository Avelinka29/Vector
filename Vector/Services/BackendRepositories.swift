import Foundation

nonisolated private struct BackendProfileProgressBody: Encodable, Sendable {
    let currentStep: Int
}

@MainActor
final class BackendUserAccountRepository: UserAccountRepository {
    private let api = BackendAPIClient.shared

    func createApplicant(id: String, email: String) async throws -> AppUser {
        AppUser(
            id: id,
            email: email,
            profileStatus: .notStarted,
            currentProfileStep: 1,
            createdAt: .now,
            updatedAt: .now
        )
    }

    func load(id: String) async throws -> AppUser? {
        let user: BackendUserDTO = try await api.request(
            "/api/v1/auth/me",
            authorized: true
        )
        let profile: BackendProfileEnvelope? = try await api.request(
            "/api/v1/profile",
            authorized: true
        )
        let status: ProfileStatus
        if let profile {
            status = profile.completionPercentage >= 100 ? .complete : .inProgress
        } else {
            status = .notStarted
        }
        return AppUser(
            id: user.id,
            email: user.email,
            profileStatus: status,
            currentProfileStep: profile?.currentStep ?? 1,
            createdAt: nil,
            updatedAt: profile?.updatedAt
        )
    }

    func updateProfileStatus(
        id: String,
        status: ProfileStatus,
        currentStep: Int
    ) async throws {
        let _: BackendProfileEnvelope = try await api.request(
            "/api/v1/profile/progress",
            method: "PATCH",
            body: BackendProfileProgressBody(currentStep: currentStep),
            authorized: true
        )
    }
}

@MainActor
final class BackendProfileRepository: ProfileRepository {
    private let api = BackendAPIClient.shared

    func loadProfile() async throws -> ApplicantProfile? {
        let response: BackendProfileEnvelope? = try await api.request(
            "/api/v1/profile",
            authorized: true
        )
        return response?.data
    }

    func saveProfile(_ profile: ApplicantProfile) async throws {
        let _: BackendProfileEnvelope = try await api.request(
            "/api/v1/profile",
            method: "PUT",
            body: BackendProfileEnvelope(profile: profile.backendSafeCopy),
            authorized: true
        )
    }
}

private extension ApplicantProfile {
    var backendSafeCopy: ApplicantProfile {
        var copy = self
        for index in copy.documents.indices {
            copy.documents[index].localURL = nil
            copy.documents[index].errorMessage = nil
            if copy.documents[index].verification?.status == .checking {
                copy.documents[index].verification = nil
            }
            if copy.documents[index].status != .uploaded {
                copy.documents[index].status = copy.documents[index].fileName == nil
                    ? .notSelected
                    : .selected
            }
        }
        for index in copy.achievements.indices {
            copy.achievements[index].supportingFileURL = nil
        }
        return copy
    }
}

nonisolated private struct BackendApplicationDTO: Codable, Sendable {
    let id: UUID
    let applicantId: UUID
    let institutionId: String
    let specialtyId: String
    let institutionName: String
    let specialtyName: String
    let studyForm: String
    let fundingType: String
    let priority: Int
    let status: ApplicationStatus
    let history: [ApplicationStatusEvent]
    let createdAt: Date
    let updatedAt: Date

    @MainActor
    var record: ApplicationRecord {
        var value = ApplicationRecord(
            id: id.uuidString.lowercased(),
            applicantID: applicantId.uuidString.lowercased(),
            institutionID: institutionId,
            institutionName: institutionName,
            specialtyID: specialtyId,
            specialtyName: specialtyName,
            studyForm: studyForm,
            fundingType: fundingType,
            priority: priority,
            status: status,
            createdAt: createdAt
        )
        value.history = history
        value.updatedAt = updatedAt
        return value
    }
}

nonisolated private struct BackendApplicationCreateBody: Encodable, Sendable {
    let id: UUID
    let institutionId: String
    let specialtyId: String
    let studyForm: String
    let fundingType: String
    let priority: Int
    let status: ApplicationStatus
}

nonisolated private struct BackendPriorityBody: Encodable, Sendable {
    let priority: Int
}

nonisolated private struct BackendPriorityItem: Encodable, Sendable {
    let id: UUID
    let priority: Int
}

nonisolated private struct BackendPrioritiesBody: Encodable, Sendable {
    let applications: [BackendPriorityItem]
}

@MainActor
final class BackendApplicationRepository: ApplicationRepository {
    private let api = BackendAPIClient.shared

    func fetch(for applicantID: String) async throws -> [ApplicationRecord] {
        let response: [BackendApplicationDTO] = try await api.request(
            "/api/v1/applications",
            authorized: true
        )
        return response.map(\.record)
    }

    func save(_ application: ApplicationRecord) async throws {
        guard let id = UUID(uuidString: application.id) else {
            throw BackendAPIError.invalidResponse
        }
        let existing = try await fetch(for: application.applicantID)
            .contains { $0.id.caseInsensitiveCompare(application.id) == .orderedSame }
        if existing {
            let _: BackendApplicationDTO = try await api.request(
                "/api/v1/applications/\(id.uuidString)/priority",
                method: "PATCH",
                body: BackendPriorityBody(priority: application.priority),
                authorized: true
            )
        } else {
            let _: BackendApplicationDTO = try await api.request(
                "/api/v1/applications",
                method: "POST",
                body: BackendApplicationCreateBody(
                    id: id,
                    institutionId: application.institutionID,
                    specialtyId: application.specialtyID,
                    studyForm: application.studyForm,
                    fundingType: application.fundingType,
                    priority: application.priority,
                    status: application.status
                ),
                authorized: true
            )
        }
    }

    func replacePriorities(_ applications: [ApplicationRecord]) async throws {
        let items = try applications.map { application in
            guard let id = UUID(uuidString: application.id) else {
                throw BackendAPIError.invalidResponse
            }
            return BackendPriorityItem(id: id, priority: application.priority)
        }
        let response: [BackendApplicationDTO] = try await api.request(
            "/api/v1/applications/priorities",
            method: "PUT",
            body: BackendPrioritiesBody(applications: items),
            authorized: true
        )
        guard response.count == applications.count else {
            throw BackendAPIError.invalidResponse
        }
    }

    func delete(id: String) async throws {
        let _: EmptyResponse = try await api.request(
            "/api/v1/applications/\(id)",
            method: "DELETE",
            authorized: true
        )
    }
}
