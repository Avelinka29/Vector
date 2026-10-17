import FirebaseFirestore
import Foundation

@MainActor
protocol UserAccountRepository {
    func createApplicant(id: String, email: String) async throws -> AppUser
    func load(id: String) async throws -> AppUser?
    func updateProfileStatus(id: String, status: ProfileStatus, currentStep: Int) async throws
}

@MainActor
final class FirestoreUserAccountRepository: UserAccountRepository {
    private let database: Firestore

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    func createApplicant(id: String, email: String) async throws -> AppUser {
        let account = AppUser(
            id: id,
            email: email,
            profileStatus: .notStarted,
            currentProfileStep: 1,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await database.collection("users").document(id).setData([
            "uid": id,
            "email": email,
            "profileStatus": ProfileStatus.notStarted.rawValue,
            "currentProfileStep": 1,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        return account
    }

    func load(id: String) async throws -> AppUser? {
        let snapshot = try await database.collection("users").document(id).getDocument()
        guard let data = snapshot.data() else { return nil }

        return AppUser(
            id: id,
            email: data["email"] as? String ?? "",
            profileStatus: ProfileStatus(rawValue: data["profileStatus"] as? String ?? "") ?? .notStarted,
            currentProfileStep: data["currentProfileStep"] as? Int ?? 1,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }

    func updateProfileStatus(
        id: String,
        status: ProfileStatus,
        currentStep: Int
    ) async throws {
        try await database.collection("users").document(id).setData([
            "profileStatus": status.rawValue,
            "currentProfileStep": currentStep,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}
