import Foundation
import Observation

@MainActor
@Observable
final class AdminInstitutionsViewModel {
    var institutions: [InstitutionRecord] = []
    var isLoading = false
    var isImportingCatalog = false
    var importResultMessage: String?
    var errorMessage: String?

    private let repository: any InstitutionRepository
    private let catalogImporter: CatalogImportService

    init(
        repository: (any InstitutionRepository)? = nil,
        catalogImporter: CatalogImportService? = nil
    ) {
        self.repository = repository ?? FirestoreInstitutionRepository()
        self.catalogImporter = catalogImporter ?? CatalogImportService()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            institutions = try await repository.fetchInstitutions()
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось загрузить учебные заведения. Проверьте интернет-соединение."
            )
        }
    }

    func save(_ institution: InstitutionRecord) async -> Bool {
        do {
            try await repository.save(institution)
            await load()
            return true
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось сохранить учебное заведение. Попробуйте ещё раз."
            )
            return false
        }
    }

    func importCatalog(from url: URL) async {
        guard !isImportingCatalog else { return }
        isImportingCatalog = true
        importResultMessage = nil
        errorMessage = nil
        defer { isImportingCatalog = false }

        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let report = try await catalogImporter.importData(data)
            importResultMessage = """
            Импорт завершён: \(report.importedInstitutionCount) учреждений,             \(report.importedSpecialtyCount) специальностей и             \(report.importedLinkCount) связей.             Дубликатов связей пропущено: \(report.skippedDuplicateLinkCount).
            """
            await load()
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось импортировать справочник. Проверьте доступ к файлу и повторите попытку."
            )
        }
    }

    func delete(id: String) async {
        do {
            try await repository.delete(id: id)
            institutions.removeAll { $0.id == id }
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось удалить учебное заведение. Попробуйте ещё раз."
            )
        }
    }
}
