import Foundation
import Observation

@MainActor
@Observable
final class InstitutionsViewModel {
    var institutions: [InstitutionRecord] = []
    var searchText = ""
    var selectedCity: String?
    var selectedType: String?
    var isLoading = false
    var errorMessage: String?

    private let repository: InstitutionRepository

    init(repository: InstitutionRepository? = nil) {
        self.repository = repository ?? FirestoreInstitutionRepository()
    }

    var cities: [String] {
        Array(Set(institutions.map(\.locality))).sorted()
    }

    var types: [String] {
        Array(Set(institutions.map(\.type))).sorted()
    }

    var filteredInstitutions: [InstitutionRecord] {
        institutions.filter { institution in
            let matchesSearch = searchText.isEmpty
                || institution.name.localizedCaseInsensitiveContains(searchText)
                || institution.locality.localizedCaseInsensitiveContains(searchText)
            let matchesCity = selectedCity == nil || institution.locality == selectedCity
            let matchesType = selectedType == nil || institution.type == selectedType
            return matchesSearch && matchesCity && matchesType
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
            errorMessage = "Не удалось загрузить учебные заведения: \(error.localizedDescription)"
        }
    }
}
