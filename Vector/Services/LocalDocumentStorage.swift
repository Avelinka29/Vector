import Foundation
import ImageIO

struct StoredLocalDocument: Sendable {
    let fileName: String
    let url: URL
    let byteCount: Int
    let mimeType: String
}

enum LocalDocumentStorageError: LocalizedError {
    case fileTooLarge
    case invalidImage
    case unavailableDirectory

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            "Фотография превышает допустимый размер 10 МБ."
        case .invalidImage:
            "Выбранный файл не удалось распознать как изображение."
        case .unavailableDirectory:
            "Не удалось открыть локальное хранилище приложения."
        }
    }
}

actor LocalDocumentStorage {
    static let maximumFileSize = 10 * 1024 * 1024

    func saveImage(
        data: Data,
        fileExtension: String,
        mimeType: String,
        userID: String,
        kind: DocumentKind
    ) throws -> StoredLocalDocument {
        guard !data.isEmpty else {
            throw LocalDocumentStorageError.invalidImage
        }
        guard CGImageSourceCreateWithData(data as CFData, nil) != nil else {
            throw LocalDocumentStorageError.invalidImage
        }
        guard data.count <= Self.maximumFileSize else {
            throw LocalDocumentStorageError.fileTooLarge
        }

        let directory = try userDirectory(userID: userID)
        let normalizedExtension = normalizedImageExtension(fileExtension)
        let fileName = "\(kind.rawValue).\(normalizedExtension)"
        let destination = directory.appendingPathComponent(fileName, isDirectory: false)

        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return StoredLocalDocument(
            fileName: fileName,
            url: destination,
            byteCount: data.count,
            mimeType: mimeType
        )
    }

    func existingURL(
        fileName: String,
        userID: String
    ) throws -> URL? {
        let url = try userDirectory(userID: userID)
            .appendingPathComponent(fileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func delete(fileName: String?, userID: String) throws {
        guard let fileName, !fileName.isEmpty else { return }
        let url = try userDirectory(userID: userID)
            .appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func userDirectory(userID: String) throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LocalDocumentStorageError.unavailableDirectory
        }

        let safeUserID = userID.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        let directory = applicationSupport
            .appendingPathComponent("VectorDocuments", isDirectory: true)
            .appendingPathComponent(safeUserID, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        return directory
    }

    private func normalizedImageExtension(_ value: String) -> String {
        switch value.lowercased() {
        case "png":
            "png"
        case "heic", "heif":
            "heic"
        default:
            "jpg"
        }
    }
}
