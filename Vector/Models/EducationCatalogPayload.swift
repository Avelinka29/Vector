import Foundation

struct BelarusEducationCatalog: Decodable, Sendable {
    var institutions: [SourceInstitution]
    var specialties: [SourceSpecialty]
    var institutionSpecialties: [SourceInstitutionSpecialty]
    var sourceRecords: [SourceRecord]
    var issues: [SourceIssue]
    var metadata: SourceMetadata

    enum CodingKeys: String, CodingKey {
        case institutions
        case specialties
        case institutionSpecialties = "institution_specialties"
        case sourceRecords = "source_records"
        case issues
        case metadata
    }
}

struct SourceInstitution: Codable, Sendable {
    var id: String
    var name: String
    var institutionType: String
    var region: String?
    var address: String?
    var sourceURL: String
    var sourceUpdatedAt: String?
    var retrievedAt: String
    var identityStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case institutionType = "institution_type"
        case region
        case address
        case sourceURL = "source_url"
        case sourceUpdatedAt = "source_updated_at"
        case retrievedAt = "retrieved_at"
        case identityStatus = "identity_status"
    }
}

struct SourceSpecialty: Codable, Sendable {
    var id: String
    var educationLevel: String
    var code: String?
    var name: String

    enum CodingKeys: String, CodingKey {
        case id
        case educationLevel = "education_level"
        case code
        case name
    }
}

struct SourceInstitutionSpecialty: Codable, Sendable {
    var institutionID: String
    var specialtyID: String
    var qualification: String?
    var sourceLabel: String
    var sourceURL: String
    var extractionStatus: String
    var sourceDetails: String?

    enum CodingKeys: String, CodingKey {
        case institutionID = "institution_id"
        case specialtyID = "specialty_id"
        case qualification
        case sourceLabel = "source_label"
        case sourceURL = "source_url"
        case extractionStatus = "extraction_status"
        case sourceDetails = "source_details"
    }
}

struct SourceRecord: Codable, Sendable {
    var institutionID: String
    var sourceURL: String
    var fields: [String: String]?
    var extractedRows: Int?
    var sourceUpdatedAt: String?

    enum CodingKeys: String, CodingKey {
        case institutionID = "institution_id"
        case sourceURL = "source_url"
        case fields
        case extractedRows = "extracted_rows"
        case sourceUpdatedAt = "source_updated_at"
    }
}

struct SourceIssue: Codable, Sendable {
    var institutionID: String?
    var error: String
    var sourceURL: String?

    enum CodingKeys: String, CodingKey {
        case institutionID = "institution_id"
        case error
        case sourceURL = "source_url"
    }
}

struct SourceMetadata: Codable, Sendable {
    var retrievedAt: String
    var country: String
    var language: String
    var coverageStatus: String
    var institutionEntries: Int
    var specialties: Int
    var institutionSpecialtyLinks: Int
    var uncodedLinks: Int
    var notes: [String]

    enum CodingKeys: String, CodingKey {
        case retrievedAt = "retrieved_at"
        case country
        case language
        case coverageStatus = "coverage_status"
        case institutionEntries = "institution_entries"
        case specialties
        case institutionSpecialtyLinks = "institution_specialty_links"
        case uncodedLinks = "uncoded_links"
        case notes
    }
}

struct InstitutionSpecialtyRecord: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var institutionID: String
    var specialtyID: String
    var qualification: String?
    var sourceLabel: String
    var sourceURL: String
    var extractionStatus: String
    var sourceDetails: String?
    var requiresVerification: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case institutionID
        case specialtyID
        case qualification
        case sourceLabel
        case sourceURL
        case extractionStatus
        case sourceDetails
        case requiresVerification
    }
}

struct CatalogSourceRecord: Codable, Identifiable, Sendable {
    var id: String
    var institutionID: String
    var sourceURL: String
    var fields: [String: String]
    var extractedRows: Int?
    var sourceUpdatedAt: String?
}

struct CatalogIssueRecord: Codable, Identifiable, Sendable {
    var id: String
    var institutionID: String?
    var message: String
    var sourceURL: String?
}

struct CatalogMetadataRecord: Codable, Sendable {
    var retrievedAt: String
    var country: String
    var language: String
    var coverageStatus: String
    var institutionEntries: Int
    var specialties: Int
    var institutionSpecialtyLinks: Int
    var uncodedLinks: Int
    var notes: [String]
    var importedAt: Date
}
