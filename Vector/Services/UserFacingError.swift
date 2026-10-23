import Foundation

enum UserFacingError {
    static func message(for error: Error, fallback: String) -> String {
        if let authenticationError = error as? AuthenticationError {
            return authenticationError.localizedDescription
        }
        if let importError = error as? CatalogImportError {
            return importError.localizedDescription
        }
        if error is DecodingError {
            return "Файл справочника имеет неподдерживаемый формат. Выберите исходный файл без изменений."
        }

        let code = (error as NSError).code
        if code == NSFileReadNoSuchFileError {
            return "Выбранный файл больше недоступен. Сохраните его в приложении «Файлы» и попробуйте снова."
        }
        return fallback
    }
}
