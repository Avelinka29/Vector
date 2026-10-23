import FirebaseFirestore
import Foundation

struct PreparedCatalogImport {
    var institutions: [InstitutionRecord]
    var specialties: [SpecialtyRecord]
    var links: [InstitutionSpecialtyRecord]
    var sourceRecords: [CatalogSourceRecord]
    var issues: [CatalogIssueRecord]
    var metadata: CatalogMetadataRecord
    var skippedDuplicateLinks: Int
}

struct CatalogImportReport: Equatable {
    var importedInstitutionCount: Int
    var importedSpecialtyCount: Int
    var importedLinkCount: Int
    var skippedDuplicateLinkCount: Int
}

enum CatalogImportError: LocalizedError {
    case unreadableFile
    case missingInstitution(linkID: String, institutionID: String)
    case missingSpecialty(linkID: String, specialtyID: String)
    case duplicateID(collection: String, id: String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "Файл справочника не удалось прочитать."
        case let .missingInstitution(linkID, institutionID):
            "Связь \(linkID) ссылается на отсутствующее учреждение \(institutionID)."
        case let .missingSpecialty(linkID, specialtyID):
            "Связь \(linkID) ссылается на отсутствующую специальность \(specialtyID)."
        case let .duplicateID(collection, id):
            "В разделе \(collection) повторяется идентификатор \(id)."
        }
    }
}

@MainActor
final class CatalogImportService {
    private let database: Firestore
    private let decoder = JSONDecoder()

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    func decode(data: Data) throws -> BelarusEducationCatalog {
        try decoder.decode(BelarusEducationCatalog.self, from: data)
    }

    func prepare(_ catalog: BelarusEducationCatalog) throws -> PreparedCatalogImport {
        try validateUniqueIDs(catalog.institutions.map(\.id), collection: "institutions")
        try validateUniqueIDs(catalog.specialties.map(\.id), collection: "specialties")

        let sourceByInstitution = Dictionary(
            catalog.sourceRecords.map { ($0.institutionID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let levelsByInstitution = Dictionary(
            grouping: catalog.institutionSpecialties,
            by: \.institutionID
        ).mapValues { links in
            let specialtyByID = Dictionary(uniqueKeysWithValues: catalog.specialties.map { ($0.id, $0) })
            return Array(Set(links.compactMap { specialtyByID[$0.specialtyID]?.educationLevel })).sorted()
        }

        let retrievedDate = parseDate(catalog.metadata.retrievedAt)
        let institutions = catalog.institutions.map { source in
            let sourceRecord = sourceByInstitution[source.id]
            var record = InstitutionRecord(
                id: source.id,
                name: source.name,
                type: normalizedInstitutionType(source.institutionType),
                locality: locality(
                    directAddress: source.address,
                    sourceAddress: sourceRecord?.fields?["Адрес"]
                ),
                regionID: source.region ?? "",
                isActive: true
            )
            record.officialID = source.id
            record.educationLevels = levelsByInstitution[source.id] ?? []
            record.coverageStatus = catalog.metadata.coverageStatus
            record.identityStatus = source.identityStatus
            record.requiresVerification = true
            record.address = source.address ?? sourceRecord?.fields?["Адрес"]
            record.websiteURL = websiteURL(from: sourceRecord?.fields?["Контакная информация"])
            record.sourceURL = source.sourceURL
            record.lastVerifiedAt = source.sourceUpdatedAt.flatMap(parseDate) ?? retrievedDate
            return record
        }

        let specialties = catalog.specialties.map { source in
            var record = SpecialtyRecord(
                id: source.id,
                institutionID: "",
                name: source.name,
                code: source.code ?? "",
                educationLevel: source.educationLevel,
                sourceURL: "",
                lastVerifiedAt: retrievedDate,
                isActive: true
            )
            record.requiresVerification = true
            return record
        }

        let institutionIDs = Set(institutions.map(\.id))
        let specialtyIDs = Set(specialties.map(\.id))
        var linksByID: [String: InstitutionSpecialtyRecord] = [:]
        var skippedDuplicates = 0

        for source in catalog.institutionSpecialties {
            let id = Self.linkID(
                institutionID: source.institutionID,
                specialtyID: source.specialtyID
            )
            guard institutionIDs.contains(source.institutionID) else {
                throw CatalogImportError.missingInstitution(
                    linkID: id,
                    institutionID: source.institutionID
                )
            }
            guard specialtyIDs.contains(source.specialtyID) else {
                throw CatalogImportError.missingSpecialty(
                    linkID: id,
                    specialtyID: source.specialtyID
                )
            }

            let record = InstitutionSpecialtyRecord(
                id: id,
                institutionID: source.institutionID,
                specialtyID: source.specialtyID,
                qualification: source.qualification,
                sourceLabel: source.sourceLabel,
                sourceURL: source.sourceURL,
                extractionStatus: source.extractionStatus,
                sourceDetails: source.sourceDetails,
                requiresVerification: true
            )
            if linksByID.updateValue(record, forKey: id) != nil {
                skippedDuplicates += 1
            }
        }

        let sourceRecords = catalog.sourceRecords.enumerated().map { index, source in
            CatalogSourceRecord(
                id: "\(source.institutionID)__\(index)",
                institutionID: source.institutionID,
                sourceURL: source.sourceURL,
                fields: source.fields ?? [:],
                extractedRows: source.extractedRows,
                sourceUpdatedAt: source.sourceUpdatedAt
            )
        }

        let issues = catalog.issues.enumerated().map { index, source in
            CatalogIssueRecord(
                id: "issue__\(source.institutionID ?? "general")__\(index)",
                institutionID: source.institutionID,
                message: source.error,
                sourceURL: source.sourceURL
            )
        }

        let metadata = CatalogMetadataRecord(
            retrievedAt: catalog.metadata.retrievedAt,
            country: catalog.metadata.country,
            language: catalog.metadata.language,
            coverageStatus: catalog.metadata.coverageStatus,
            institutionEntries: catalog.metadata.institutionEntries,
            specialties: catalog.metadata.specialties,
            institutionSpecialtyLinks: catalog.metadata.institutionSpecialtyLinks,
            uncodedLinks: catalog.metadata.uncodedLinks,
            notes: catalog.metadata.notes,
            importedAt: Date()
        )

        return PreparedCatalogImport(
            institutions: institutions,
            specialties: specialties,
            links: linksByID.values.sorted { $0.id < $1.id },
            sourceRecords: sourceRecords,
            issues: issues,
            metadata: metadata,
            skippedDuplicateLinks: skippedDuplicates
        )
    }

    func importData(_ data: Data) async throws -> CatalogImportReport {
        let prepared = try prepare(decode(data: data))
        try await write(prepared)
        return CatalogImportReport(
            importedInstitutionCount: prepared.institutions.count,
            importedSpecialtyCount: prepared.specialties.count,
            importedLinkCount: prepared.links.count,
            skippedDuplicateLinkCount: prepared.skippedDuplicateLinks
        )
    }

    private func write(_ prepared: PreparedCatalogImport) async throws {
        var writes: [(DocumentReference, [String: Any])] = []

        for value in prepared.institutions {
            writes.append((
                database.collection("institutions").document(value.id),
                try Firestore.Encoder().encode(value)
            ))
        }
        for value in prepared.specialties {
            writes.append((
                database.collection("specialties").document(value.id),
                try Firestore.Encoder().encode(value)
            ))
        }
        for value in prepared.links {
            writes.append((
                database.collection("institution_specialties").document(value.id),
                try Firestore.Encoder().encode(value)
            ))
        }
        for value in prepared.sourceRecords {
            writes.append((
                database.collection("catalog_source_records").document(value.id),
                try Firestore.Encoder().encode(value)
            ))
        }
        for value in prepared.issues {
            writes.append((
                database.collection("catalog_issues").document(value.id),
                try Firestore.Encoder().encode(value)
            ))
        }
        writes.append((
            database.collection("catalog_metadata").document("belarus_education"),
            try Firestore.Encoder().encode(prepared.metadata)
        ))

        for chunk in writes.chunked(maxCount: 450) {
            let batch = database.batch()
            for (reference, data) in chunk {
                batch.setData(data, forDocument: reference, merge: true)
            }
            try await batch.commit()
        }
    }

    private func validateUniqueIDs(_ ids: [String], collection: String) throws {
        var seen = Set<String>()
        for id in ids where !seen.insert(id).inserted {
            throw CatalogImportError.duplicateID(collection: collection, id: id)
        }
    }

    private func parseDate(_ value: String) -> Date? {
        for format in ["yyyy-MM-dd", "dd.MM.yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private func normalizedInstitutionType(_ value: String) -> String {
        if value.contains("higher") {
            return "university"
        }
        if value.contains("secondary") || value.contains("college") {
            return "college"
        }
        return value
    }

    private func locality(directAddress: String?, sourceAddress: String?) -> String {
        let address = directAddress ?? sourceAddress ?? ""
        let patterns = [
            #"г\.\s*([^,\n]+)"#,
            #"город\s+([^,\n]+)"#
        ]
        for pattern in patterns {
            if let range = address.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                return address[range]
                    .replacingOccurrences(of: "г.", with: "")
                    .replacingOccurrences(of: "город", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private func websiteURL(from contactInformation: String?) -> String? {
        guard let contactInformation else { return nil }
        let pattern = #"https?://[^\s,;]+|www\.[^\s,;]+"#
        guard let range = contactInformation.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let value = String(contactInformation[range])
        return value.hasPrefix("http") ? value : "https://\(value)"
    }

    static func linkID(institutionID: String, specialtyID: String) -> String {
        "\(institutionID)__\(specialtyID)"
    }
}

private extension Array {
    func chunked(maxCount: Int) -> [[Element]] {
        guard maxCount > 0 else { return [] }
        return stride(from: 0, to: count, by: maxCount).map { start in
            Array(self[start..<Swift.min(start + maxCount, count)])
        }
    }
}
