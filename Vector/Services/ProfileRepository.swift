import FirebaseFirestore
import Foundation

@MainActor
protocol ProfileRepository {
    func loadProfile() async throws -> ApplicantProfile?
    func saveProfile(_ profile: ApplicantProfile) async throws
}

enum ProfileRepositoryError: LocalizedError {
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "Не удалось сохранить профиль."
        case .decodingFailed: "Не удалось прочитать сохранённый профиль."
        }
    }
}

@MainActor
final class LocalProfileRepository: ProfileRepository {
    private let defaults: UserDefaults
    private let storageKey: String

    init(userID: String = "guest", defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.storageKey = "vector.applicant.profile.\(userID)"
    }

    func loadProfile() async throws -> ApplicantProfile? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(ApplicantProfile.self, from: data)
        } catch {
            throw ProfileRepositoryError.decodingFailed
        }
    }

    func saveProfile(_ profile: ApplicantProfile) async throws {
        do {
            let data = try JSONEncoder().encode(profile)
            defaults.set(data, forKey: storageKey)
        } catch {
            throw ProfileRepositoryError.encodingFailed
        }
    }
}

@MainActor
final class FirestoreProfileRepository: ProfileRepository {
    private let document: DocumentReference

    init(userID: String, database: Firestore = Firestore.firestore()) {
        self.document = database.collection("applicantProfiles").document(userID)
    }

    func loadProfile() async throws -> ApplicantProfile? {
        let snapshot = try await document.getDocument()
        guard snapshot.exists else { return nil }

        do {
            return try snapshot.data(as: ApplicantProfile.self)
        } catch {
            throw ProfileRepositoryError.decodingFailed
        }
    }

    func saveProfile(_ profile: ApplicantProfile) async throws {
        let encodedProfile: [String: Any]

        do {
            encodedProfile = try Firestore.Encoder().encode(profile.firestoreSafeCopy)
        } catch {
            throw ProfileRepositoryError.encodingFailed
        }

        try await document.setData(encodedProfile, merge: true)
    }
}

private extension ApplicantProfile {
    var firestoreSafeCopy: ApplicantProfile {
        var copy = self

        for index in copy.documents.indices {
            copy.documents[index].localURL = nil
            copy.documents[index].errorMessage = nil
            if copy.documents[index].verification?.status == .checking {
                copy.documents[index].verification = nil
            }
            if copy.documents[index].status != .uploaded {
                copy.documents[index].status = copy.documents[index].fileName == nil
                    ? .notSelected
                    : .selected
            }
        }

        for index in copy.achievements.indices {
            copy.achievements[index].supportingFileURL = nil
        }

        return copy
    }
}

protocol DocumentUploading {
    func upload(document: ProfileDocument) async throws -> ProfileDocument
}

struct PendingDocumentUploader: DocumentUploading {
    func upload(document: ProfileDocument) async throws -> ProfileDocument {
        document
    }
}
