import Foundation
import Observation

@MainActor
@Observable
final class AdminInstitutionsViewModel {
    var institutions: [InstitutionRecord] = []
    var isLoading = false
    var errorMessage: String?

    private let repository: any InstitutionRepository

    init(repository: (any InstitutionRepository)? = nil) {
        self.repository = repository ?? FirestoreInstitutionRepository()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            institutions = try await repository.fetchInstitutions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(_ institution: InstitutionRecord) async -> Bool {
        do {
            try await repository.save(institution)
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(id: String) async {
        do {
            try await repository.delete(id: id)
            institutions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
