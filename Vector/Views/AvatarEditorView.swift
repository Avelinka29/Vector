import FirebaseAuth
import PhotosUI
import SwiftUI
import UIKit

@MainActor
protocol AvatarStorage {
    func load(userID: String) throws -> Data?
    func save(_ data: Data, userID: String) throws
    func delete(userID: String) throws
}

@MainActor
final class LocalAvatarStorage: AvatarStorage {
    static let shared = LocalAvatarStorage()

    private let fileManager = FileManager.default

    func load(userID: String) throws -> Data? {
        let url = try avatarURL(userID: userID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func save(_ data: Data, userID: String) throws {
        let url = try avatarURL(userID: userID)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func delete(userID: String) throws {
        let url = try avatarURL(userID: userID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func avatarURL(userID: String) throws -> URL {
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let safeID = userID.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        return baseURL
            .appendingPathComponent("Avatars", isDirectory: true)
            .appendingPathComponent("\(safeID).jpg")
    }
}

struct AvatarEditorView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    private let storage: any AvatarStorage

    init(storage: any AvatarStorage = LocalAvatarStorage.shared) {
        self.storage = storage
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 18) {
                    avatarPreview

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(
                            avatarImage == nil ? "Выбрать фотографию" : "Заменить фотографию",
                            systemImage: "photo.on.rectangle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.systemBlue01)
                    .disabled(isProcessing)

                    if avatarImage != nil {
                        Button("Удалить аватар", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .disabled(isProcessing)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } footer: {
                Text("Фотография обрезается по центру до квадрата и хранится только на этом устройстве.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Аватар")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isProcessing {
                ProgressView("Обрабатываем фотографию…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task { loadAvatar() }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .confirmationDialog(
            "Удалить аватар?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive, action: deleteAvatar)
            Button("Отмена", role: .cancel) {}
        }
    }

    private var avatarPreview: some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.systemBlue01.opacity(0.72))
                    .padding(14)
            }
        }
        .frame(width: 170, height: 170)
        .background(.systemBlue01.opacity(0.08))
        .clipShape(Circle())
        .overlay {
            Circle().stroke(.systemGrey1.opacity(0.4), lineWidth: 1)
        }
        .accessibilityLabel(avatarImage == nil ? "Аватар не выбран" : "Предпросмотр аватара")
    }

    @MainActor
    private func loadAvatar() {
        guard let userID else { return }
        do {
            if let data = try storage.load(userID: userID) {
                avatarImage = UIImage(data: data)
            }
        } catch {
            errorMessage = "Не удалось загрузить аватар: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            guard
                let sourceData = try await item.loadTransferable(type: Data.self),
                let sourceImage = UIImage(data: sourceData),
                let croppedImage = sourceImage.centerSquareImage(maxPixelSize: 1024),
                let encoded = croppedImage.jpegData(compressionQuality: 0.86),
                let userID
            else {
                throw AvatarError.invalidImage
            }

            try storage.save(encoded, userID: userID)
            avatarImage = croppedImage
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось сохранить фотографию: \(error.localizedDescription)"
        }
        selectedItem = nil
    }

    @MainActor
    private func deleteAvatar() {
        guard let userID else { return }
        do {
            try storage.delete(userID: userID)
            avatarImage = nil
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось удалить аватар: \(error.localizedDescription)"
        }
    }

    private var userID: String? {
        Auth.auth().currentUser?.uid
    }
}

private enum AvatarError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "Выбранный файл не удалось обработать как изображение."
    }
}

private extension UIImage {
    func centerSquareImage(maxPixelSize: CGFloat) -> UIImage? {
        guard let cgImage else { return nil }

        let side = min(cgImage.width, cgImage.height)
        let originX = (cgImage.width - side) / 2
        let originY = (cgImage.height - side) / 2
        guard let square = cgImage.cropping(
            to: CGRect(x: originX, y: originY, width: side, height: side)
        ) else {
            return nil
        }

        let outputSize = min(CGFloat(side), maxPixelSize)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { _ in
            UIImage(cgImage: square, scale: scale, orientation: imageOrientation)
                .draw(in: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
        }
    }
}

#Preview {
    NavigationStack {
        AvatarEditorView()
    }
}
