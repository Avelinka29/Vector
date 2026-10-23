import Foundation
import Observation

@MainActor
@Observable
final class InstitutionsViewModel {
    var institutions: [InstitutionRecord] = []
    var searchText = ""
    var selectedCity: String?
    var selectedRegionID: String?
    var selectedType: String?
    var selectedEducationLevel: String?
    var isLoading = false
    var errorMessage: String?

    private let repository: InstitutionRepository

    init(repository: InstitutionRepository? = nil) {
        self.repository = repository ?? BackendCatalogInstitutionRepository()
    }

    var cities: [String] {
        Array(Set(institutions.map(\.locality))).sorted()
    }

    var regionIDs: [String] {
        Array(Set(institutions.map(\.regionID).filter { !$0.isEmpty })).sorted()
    }

    var types: [String] {
        Array(Set(institutions.map(\.type))).sorted()
    }

    var educationLevels: [String] {
        Array(Set(institutions.flatMap { $0.educationLevels ?? [] })).sorted()
    }

    var filteredInstitutions: [InstitutionRecord] {
        institutions.filter { institution in
            let matchesSearch = searchText.isEmpty
                || institution.name.localizedCaseInsensitiveContains(searchText)
                || institution.locality.localizedCaseInsensitiveContains(searchText)
            let matchesCity = selectedCity == nil || institution.locality == selectedCity
            let matchesRegion = selectedRegionID == nil || institution.regionID == selectedRegionID
            let matchesType = selectedType == nil || institution.type == selectedType
            let matchesLevel = selectedEducationLevel == nil
                || institution.educationLevels?.contains(selectedEducationLevel ?? "") == true
            return matchesSearch && matchesCity && matchesRegion && matchesType && matchesLevel
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            institutions = try await repository.fetchPublishedInstitutions()
        } catch {
            errorMessage = "Не удалось загрузить учебные заведения. Проверьте интернет-соединение."
        }
    }
}
