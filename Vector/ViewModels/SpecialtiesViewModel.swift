import Foundation
import Observation

@MainActor
@Observable
final class SpecialtiesViewModel {
    var specialties: [SpecialtyRecord] = []
    var institutions: [InstitutionRecord] = []
    var searchText = "" {
        didSet { recomputeVisibleSpecialties() }
    }
    var selectedInstitutionID: String? {
        didSet { recomputeVisibleSpecialties() }
    }
    var isLoading = false
    var errorMessage: String?
    private(set) var visibleSpecialties: [SpecialtyRecord] = []

    private let specialtyRepository: SpecialtyRepository
    private let institutionRepository: InstitutionRepository

    init(
        specialtyRepository: SpecialtyRepository? = nil,
        institutionRepository: InstitutionRepository? = nil
    ) {
        self.specialtyRepository = specialtyRepository ?? FirestoreSpecialtyRepository()
        self.institutionRepository = institutionRepository ?? FirestoreInstitutionRepository()
    }

    func load(institutionID: String? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        selectedInstitutionID = institutionID
        defer { isLoading = false }

        do {
            async let specialtiesRequest = specialtyRepository.fetchPublishedSpecialties(institutionID: nil)
            async let institutionsRequest = institutionRepository.fetchPublishedInstitutions()
            specialties = try await specialtiesRequest
            institutions = try await institutionsRequest
            recomputeVisibleSpecialties()
        } catch {
            errorMessage = "Не удалось загрузить специальности: \(error.localizedDescription)"
        }
    }

    func institutionName(for id: String) -> String {
        institutions.first(where: { $0.id == id })?.name ?? "Учебное заведение"
    }

    private func recomputeVisibleSpecialties() {
        visibleSpecialties = specialties.filter { specialty in
            let institutionName = institutionName(for: specialty.institutionID)
            let matchesSearch = searchText.isEmpty
                || specialty.name.localizedCaseInsensitiveContains(searchText)
                || specialty.code.localizedCaseInsensitiveContains(searchText)
                || institutionName.localizedCaseInsensitiveContains(searchText)
            let matchesInstitution = selectedInstitutionID == nil
                || specialty.institutionID == selectedInstitutionID
            return matchesSearch && matchesInstitution
        }
    }
}
