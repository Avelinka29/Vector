import FirebaseFirestore
import Foundation

@MainActor
protocol InstitutionRepository {
    func fetchInstitutions() async throws -> [InstitutionRecord]
    func fetchPublishedInstitutions() async throws -> [InstitutionRecord]
    func save(_ institution: InstitutionRecord) async throws
    func delete(id: String) async throws
}

@MainActor
final class FirestoreInstitutionRepository: InstitutionRepository {
    private let collection: CollectionReference

    init(database: Firestore = Firestore.firestore()) {
        self.collection = database.collection("institutions")
    }

    func fetchInstitutions() async throws -> [InstitutionRecord] {
        let snapshot = try await collection.order(by: "name").getDocuments()
        return try snapshot.documents.map { document in
            var institution = try document.data(as: InstitutionRecord.self)
            institution.id = document.documentID
            return institution
        }
    }

    func fetchPublishedInstitutions() async throws -> [InstitutionRecord] {
        let snapshot = try await collection
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.map { document in
            var institution = try document.data(as: InstitutionRecord.self)
            institution.id = document.documentID
            return institution
        }
        .sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func save(_ institution: InstitutionRecord) async throws {
        try collection.document(institution.id).setData(from: institution, merge: true)
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }
}
