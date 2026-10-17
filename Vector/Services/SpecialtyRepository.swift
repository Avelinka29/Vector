import FirebaseFirestore
import Foundation

@MainActor
protocol SpecialtyRepository {
    func fetchPublishedSpecialties(institutionID: String?) async throws -> [SpecialtyRecord]
}

@MainActor
final class FirestoreSpecialtyRepository: SpecialtyRepository {
    private let collection: CollectionReference

    init(database: Firestore = Firestore.firestore()) {
        collection = database.collection("specialties")
    }

    func fetchPublishedSpecialties(institutionID: String? = nil) async throws -> [SpecialtyRecord] {
        var query: Query = collection.whereField("isActive", isEqualTo: true)
        if let institutionID {
            query = query.whereField("institutionID", isEqualTo: institutionID)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { document in
            var specialty = try document.data(as: SpecialtyRecord.self)
            specialty.id = document.documentID
            return specialty
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
