import Foundation
import ImageIO
import OSLog
import UIKit
@preconcurrency import Vision

enum DocumentRecognitionError: LocalizedError {
    case unreadableImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "Не удалось открыть фотографию для проверки."
        case .recognitionFailed:
            "Не удалось выполнить распознавание текста."
        }
    }
}

actor DocumentRecognitionService {
    func verify(
        imageData: Data,
        kind: DocumentKind,
        expected: ExpectedDocumentData
    ) throws -> DocumentVerification {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw DocumentRecognitionError.unreadableImage
        }

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.automaticallyDetectsLanguage = true
        textRequest.customWords = [
            "ПАСПАРТ", "РЭСПУБЛІКА", "БЕЛАРУСЬ", "АТТЕСТАТ",
            "СЕРТИФИКАТ", "ЦЭ", "ЦТ"
        ]

        let supportedLanguages = (try? textRequest.supportedRecognitionLanguages()) ?? []
        let preferredLanguages = ["ru-RU", "en-US"].filter(supportedLanguages.contains)
        if !preferredLanguages.isEmpty {
            textRequest.recognitionLanguages = preferredLanguages
        }

        let faceRequest = VNDetectFaceRectanglesRequest()
        #if targetEnvironment(simulator)
        // The simulator may not provide a usable GPU inference context.
        textRequest.usesCPUOnly = true
        faceRequest.usesCPUOnly = true
        #endif
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )

        // Preserve OCR results if the separate face detector is unavailable.
        if kind != .portrait {
            do {
                try handler.perform([textRequest])
            } catch {
                throw DocumentRecognitionError.recognitionFailed
            }
        }
        var faceDetectionFailed = false
        if kind == .passport || kind == .portrait {
            do {
                try handler.perform([faceRequest])
            } catch {
                faceDetectionFailed = true
                let failure = error as NSError
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vector", category: "DocumentRecognition")
                    .error("Face detection failed: code=\(failure.code)")
            }
        }

        let candidates = (textRequest.results ?? []).compactMap {
            $0.topCandidates(1).first
        }
        let recognizedText = candidates.map(\.string).joined(separator: " ")
        let averageConfidence: Double
        if candidates.isEmpty {
            averageConfidence = 0
        } else {
            averageConfidence = candidates
                .map { Double($0.confidence) }
                .reduce(0, +) / Double(candidates.count)
        }

        let faceCount = faceRequest.results?.count ?? 0
        var verification = DocumentVerificationEvaluator().evaluate(
            kind: kind,
            recognizedText: recognizedText,
            averageOCRConfidence: averageConfidence,
            faceCount: faceCount,
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height,
            expected: expected
        )
        if faceDetectionFailed {
            verification.status = .needsReview
            verification.warnings.removeAll { $0.contains("не обнаружено") }
            verification.warnings.append("Проверка лица недоступна. Текст проверен отдельно; документ требует ручной проверки.")
        }
        return verification
    }

}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
