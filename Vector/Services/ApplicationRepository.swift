import FirebaseFirestore
import Foundation

@MainActor
protocol ApplicationRepository {
    func fetch(for applicantID: String) async throws -> [ApplicationRecord]
    func save(_ application: ApplicationRecord) async throws
    func replacePriorities(_ applications: [ApplicationRecord]) async throws
    func delete(id: String) async throws
}

@MainActor
final class FirestoreApplicationRepository: ApplicationRepository {
    private let collection: CollectionReference

    init(database: Firestore = Firestore.firestore()) {
        collection = database.collection("applications")
    }

    func fetch(for applicantID: String) async throws -> [ApplicationRecord] {
        let snapshot = try await collection
            .whereField("applicantID", isEqualTo: applicantID)
            .getDocuments()

        return try snapshot.documents
            .map { try $0.data(as: ApplicationRecord.self) }
            .sorted {
                if $0.priority == $1.priority { return $0.createdAt > $1.createdAt }
                return $0.priority < $1.priority
            }
    }

    func save(_ application: ApplicationRecord) async throws {
        try collection.document(application.id).setData(from: application, merge: true)
    }

    func replacePriorities(_ applications: [ApplicationRecord]) async throws {
        let batch = collection.firestore.batch()
        for application in applications {
            batch.updateData(
                ["priority": application.priority, "updatedAt": application.updatedAt],
                forDocument: collection.document(application.id)
            )
        }
        try await batch.commit()
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }
}
