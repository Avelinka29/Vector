import Foundation

nonisolated private struct BackendOrganizationCreateBody: Encodable, Sendable {
    let type: OrganizationType
    let name: String
    let legalName: String
    let taxId: String
    let city: String
    let website: URL?
    let description: String
}

nonisolated private struct BackendOrganizationStatusBody: Encodable, Sendable {
    let status: OrganizationVerificationStatus
}

@MainActor
final class OrganizationService {
    private let api = BackendAPIClient.shared

    func loadMine() async throws -> OrganizationRecord? {
        try await api.request(
            "/api/v1/organizations/mine",
            authorized: true
        )
    }

    func apply(_ draft: OrganizationApplicationDraft) async throws -> OrganizationRecord {
        let website = draft.website.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await api.request(
            "/api/v1/organizations/applications",
            method: "POST",
            body: BackendOrganizationCreateBody(
                type: draft.type,
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                legalName: draft.legalName.trimmingCharacters(in: .whitespacesAndNewlines),
                taxId: draft.taxId.trimmingCharacters(in: .whitespacesAndNewlines),
                city: draft.city.trimmingCharacters(in: .whitespacesAndNewlines),
                website: website.isEmpty ? nil : URL(string: website),
                description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            authorized: true
        )
    }

    func loadForModeration(
        status: OrganizationVerificationStatus? = nil
    ) async throws -> [OrganizationRecord] {
        let organizations: [OrganizationRecord] = try await api.request(
            "/api/v1/organizations/admin",
            authorized: true
        )
        guard let status else { return organizations }
        return organizations.filter { $0.status == status }
    }

    func updateStatus(
        organizationID: UUID,
        status: OrganizationVerificationStatus
    ) async throws -> OrganizationRecord {
        try await api.request(
            "/api/v1/organizations/\(organizationID.uuidString)/status",
            method: "PATCH",
            body: BackendOrganizationStatusBody(status: status),
            authorized: true
        )
    }
}
