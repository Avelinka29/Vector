import Foundation

nonisolated private struct CatalogInstitutionDTO: Decodable, Sendable {
    let id, name, type, locality, regionId: String
    let address, websiteUrl, admissionsPhone, admissionsEmail, admissionsUrl, sourceUrl: String
    let educationLevels: [String]?
    let lastVerifiedAt: String?
    let needsVerification: Bool

    @MainActor var record: InstitutionRecord {
        var result = InstitutionRecord(id: id, name: name, type: type, locality: locality, regionID: regionId)
        result.educationLevels = educationLevels?.map(catalogLevel)
        result.address = address
        result.websiteURL = websiteUrl
        result.admissionsPhone = admissionsPhone
        result.admissionsEmail = admissionsEmail
        result.admissionsURL = admissionsUrl
        result.sourceURL = sourceUrl
        result.requiresVerification = needsVerification
        result.lastVerifiedAt = catalogDate(lastVerifiedAt)
        return result
    }
}

nonisolated private struct CatalogSpecialtyDTO: Decodable, Sendable {
    let id, institutionId, name, code, educationLevel, qualification, sourceUrl: String
    let studyForms: [String]
    let lastVerifiedAt: String?
    let needsVerification: Bool

    @MainActor var record: SpecialtyRecord {
        var result = SpecialtyRecord(id: id, institutionID: institutionId, name: name, code: code,
                                     qualification: qualification, educationLevel: catalogLevel(educationLevel),
                                     studyForms: studyForms, sourceURL: sourceUrl,
                                     lastVerifiedAt: catalogDate(lastVerifiedAt))
        result.requiresVerification = needsVerification
        return result
    }
    @MainActor var link: InstitutionSpecialtyRecord {
        InstitutionSpecialtyRecord(id: institutionId + ":" + id, institutionID: institutionId,
                                   specialtyID: id, qualification: qualification, sourceLabel: "",
                                   sourceURL: sourceUrl, extractionStatus: "", sourceDetails: nil,
                                   requiresVerification: needsVerification)
    }
}

nonisolated private func catalogLevel(_ value: String) -> String {
    ["higher": "Высшее", "master": "Магистратура", "secondary_special": "Среднее специальное", "vocational": "Профессионально-техническое"][value] ?? value
}

@MainActor private func catalogDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
}

@MainActor final class BackendCatalogInstitutionRepository: InstitutionRepository {
    func fetchInstitutions() async throws -> [InstitutionRecord] { try await fetchPublishedInstitutions() }
    func fetchPublishedInstitutions() async throws -> [InstitutionRecord] {
        var all: [CatalogInstitutionDTO] = []
        while true {
            let page: [CatalogInstitutionDTO] = try await BackendAPIClient.shared.request(
                "/api/v1/catalog/institutions", queryItems: [URLQueryItem(name: "limit", value: "200"), URLQueryItem(name: "offset", value: String(all.count))])
            all += page
            if page.count < 200 { break }
        }
        return all.map(\.record)
    }
    func save(_ institution: InstitutionRecord) async throws {
        throw BackendAPIError.server(message: "Измените профиль в кабинете учреждения.")
    }
    func delete(id: String) async throws {
        throw BackendAPIError.server(message: "Управление публикацией доступно в кабинете учреждения.")
    }
}

@MainActor final class BackendCatalogSpecialtyRepository: SpecialtyRepository {
    private var pending: Task<[CatalogSpecialtyDTO], Error>?
    private func rows() async throws -> [CatalogSpecialtyDTO] {
        if let pending { return try await pending.value }
        let task = Task { () throws -> [CatalogSpecialtyDTO] in
            var all: [CatalogSpecialtyDTO] = []
            while true {
                let page: [CatalogSpecialtyDTO] = try await BackendAPIClient.shared.request(
                    "/api/v1/catalog/specialties", queryItems: [URLQueryItem(name: "limit", value: "200"), URLQueryItem(name: "offset", value: String(all.count))])
                all += page
                if page.count < 200 { break }
            }
            return all
        }
        pending = task
        defer { pending = nil }
        return try await task.value
    }
    func fetchPublishedSpecialties(institutionID: String?) async throws -> [SpecialtyRecord] {
        let filtered = try await rows().filter { institutionID == nil || $0.institutionId == institutionID }
        var seen = Set<String>()
        return filtered.filter { seen.insert($0.id).inserted }.map(\.record)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func fetchLinks(institutionID: String?) async throws -> [InstitutionSpecialtyRecord] {
        try await rows().filter { institutionID == nil || $0.institutionId == institutionID }.map(\.link)
    }
    func save(_ specialty: SpecialtyRecord) async throws {
        throw BackendAPIError.server(message: "Измените программу в кабинете учреждения.")
    }
}
