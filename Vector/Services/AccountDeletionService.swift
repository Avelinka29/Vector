import FirebaseFirestore
import Foundation

@MainActor
final class AccountDeletionService {
    private let database: Firestore
    private let avatarStorage: any AvatarStorage

    init(
        database: Firestore = Firestore.firestore(),
        avatarStorage: any AvatarStorage = LocalAvatarStorage.shared
    ) {
        self.database = database
        self.avatarStorage = avatarStorage
    }

    func deleteData(userID: String) async throws {
        let applications = try await database.collection("applications")
            .whereField("applicantID", isEqualTo: userID)
            .getDocuments()

        let batch = database.batch()
        applications.documents.forEach { batch.deleteDocument($0.reference) }
        batch.deleteDocument(database.collection("applicantProfiles").document(userID))
        batch.deleteDocument(database.collection("users").document(userID))
        try await batch.commit()
        try? avatarStorage.delete(userID: userID)
    }
}
