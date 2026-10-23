import Foundation
import Observation

@MainActor
@Observable
final class SpecialtiesViewModel {
    var specialties: [SpecialtyRecord] = []
    var institutions: [InstitutionRecord] = []
    var links: [InstitutionSpecialtyRecord] = []
    var searchText = "" {
        didSet { recomputeVisibleSpecialties() }
    }
    var selectedInstitutionID: String? {
        didSet { recomputeVisibleSpecialties() }
    }
    var selectedEducationLevel: String? {
        didSet { recomputeVisibleSpecialties() }
    }
    var selectedStudyForm: String? {
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
        self.specialtyRepository = specialtyRepository ?? BackendCatalogSpecialtyRepository()
        self.institutionRepository = institutionRepository ?? BackendCatalogInstitutionRepository()
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
            async let linksRequest = specialtyRepository.fetchLinks(institutionID: nil)
            specialties = try await specialtiesRequest
            institutions = try await institutionsRequest
            links = try await linksRequest
            recomputeVisibleSpecialties()
        } catch {
            errorMessage = "Не удалось загрузить специальности. Проверьте интернет-соединение."
        }
    }

    var educationLevels: [String] {
        Array(Set(specialties.compactMap(\.educationLevel))).sorted()
    }

    var studyForms: [String] {
        Array(Set(specialties.flatMap(\.studyForms))).sorted()
    }

    func institutionName(for id: String) -> String {
        institutions.first(where: { $0.id == id })?.name ?? "Учебное заведение"
    }

    func institutionNames(for specialtyID: String) -> String {
        let institutionIDs = Set(
            links
                .filter { $0.specialtyID == specialtyID }
                .map(\.institutionID)
        )
        let names = institutions
            .filter { institutionIDs.contains($0.id) }
            .map(\.name)
            .sorted()
        return names.isEmpty ? "Учреждение не указано" : names.formatted()
    }

    func institutions(for specialtyID: String) -> [InstitutionRecord] {
        let institutionIDs = Set(
            links.filter { $0.specialtyID == specialtyID }.map(\.institutionID)
        )
        return institutions.filter { institutionIDs.contains($0.id) }
    }

    private func recomputeVisibleSpecialties() {
        visibleSpecialties = specialties.filter { specialty in
            let institutionNames = institutionNames(for: specialty.id)
            let matchesSearch = searchText.isEmpty
                || specialty.name.localizedCaseInsensitiveContains(searchText)
                || specialty.code.localizedCaseInsensitiveContains(searchText)
                || institutionNames.localizedCaseInsensitiveContains(searchText)
            let matchesInstitution = selectedInstitutionID == nil
                || links.contains {
                    $0.specialtyID == specialty.id
                        && $0.institutionID == selectedInstitutionID
                }
            let matchesLevel = selectedEducationLevel == nil
                || specialty.educationLevel == selectedEducationLevel
            let matchesForm = selectedStudyForm == nil
                || specialty.studyForms.contains(selectedStudyForm ?? "")
            return matchesSearch && matchesInstitution && matchesLevel && matchesForm
        }
    }
}
