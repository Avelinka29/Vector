import FirebaseFirestore
import Foundation

@MainActor
protocol SpecialtyRepository {
    func fetchPublishedSpecialties(institutionID: String?) async throws -> [SpecialtyRecord]
    func fetchLinks(institutionID: String?) async throws -> [InstitutionSpecialtyRecord]
    func save(_ specialty: SpecialtyRecord) async throws
}

@MainActor
final class FirestoreSpecialtyRepository: SpecialtyRepository {
    private let database: Firestore
    private let collection: CollectionReference
    private let linksCollection: CollectionReference

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
        collection = database.collection("specialties")
        linksCollection = database.collection("institution_specialties")
    }

    func fetchPublishedSpecialties(institutionID: String? = nil) async throws -> [SpecialtyRecord] {
        let snapshot = try await collection
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        let allSpecialties = try snapshot.documents.map { document in
            var specialty = try document.data(as: SpecialtyRecord.self)
            specialty.id = document.documentID
            return specialty
        }

        guard let institutionID else {
            return allSpecialties.sorted(by: specialtySort)
        }

        let links = try await fetchLinks(institutionID: institutionID)
        let linkBySpecialtyID = Dictionary(
            links.map { ($0.specialtyID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return allSpecialties.compactMap { specialty in
            guard let link = linkBySpecialtyID[specialty.id] else { return nil }
            var linkedSpecialty = specialty
            linkedSpecialty.institutionID = institutionID
            linkedSpecialty.qualification = link.qualification
            linkedSpecialty.sourceURL = link.sourceURL
            linkedSpecialty.requiresVerification = link.requiresVerification
            return linkedSpecialty
        }
        .sorted(by: specialtySort)
    }

    func fetchLinks(institutionID: String? = nil) async throws -> [InstitutionSpecialtyRecord] {
        var query: Query = linksCollection
        if let institutionID {
            query = query.whereField("institutionID", isEqualTo: institutionID)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { document in
            var link = try document.data(as: InstitutionSpecialtyRecord.self)
            link.id = document.documentID
            return link
        }
    }

    func save(_ specialty: SpecialtyRecord) async throws {
        try collection.document(specialty.id).setData(from: specialty, merge: true)
    }

    private func specialtySort(_ lhs: SpecialtyRecord, _ rhs: SpecialtyRecord) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
