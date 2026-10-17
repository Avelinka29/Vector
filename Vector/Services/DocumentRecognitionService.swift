import Foundation
import ImageIO
import UIKit
@preconcurrency import Vision

struct ExpectedDocumentData: Sendable {
    let firstName: String
    let lastName: String
    let patronymic: String
    let birthDate: Date?
    let passportNumber: String
}

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
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )

        do {
            try handler.perform([textRequest, faceRequest])
        } catch {
            throw DocumentRecognitionError.recognitionFailed
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
        return evaluate(
            kind: kind,
            recognizedText: recognizedText,
            averageOCRConfidence: averageConfidence,
            faceCount: faceCount,
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height,
            expected: expected
        )
    }

    private func evaluate(
        kind: DocumentKind,
        recognizedText: String,
        averageOCRConfidence: Double,
        faceCount: Int,
        pixelWidth: Int,
        pixelHeight: Int,
        expected: ExpectedDocumentData
    ) -> DocumentVerification {
        let text = normalize(recognizedText)
        let hasMinimumResolution = pixelWidth >= 700 && pixelHeight >= 700
        var checks: [String] = []
        var warnings: [String] = []

        if hasMinimumResolution {
            checks.append("Достаточное разрешение фотографии")
        } else {
            warnings.append("Используйте фотографию с разрешением не меньше 700×700.")
        }

        switch kind {
        case .passport:
            let hasPassportWords = containsAny(
                ["ПАСПАРТ", "PASSPORT", "РЭСПУБЛІКА БЕЛАРУСЬ", "REPUBLIC OF BELARUS"],
                in: text
            )
            if hasPassportWords {
                checks.append("Найдены признаки паспорта")
            } else {
                warnings.append("Не найдены надписи, характерные для паспорта.")
            }

            if faceCount > 0 {
                checks.append("Обнаружена фотография владельца")
            } else {
                warnings.append("На паспортном развороте не обнаружено лицо.")
            }

            appendIdentityChecks(text: text, expected: expected, checks: &checks, warnings: &warnings)
            let score = score(
                quality: hasMinimumResolution,
                primaryEvidence: hasPassportWords,
                secondaryEvidence: faceCount > 0,
                confidence: averageOCRConfidence
            )
            return result(
                likelyMatches: hasMinimumResolution && hasPassportWords && faceCount > 0,
                confidence: score,
                checks: checks,
                warnings: warnings
            )

        case .certificate:
            let hasCertificateWords = containsAny(
                ["АТТЕСТАТ", "ОБЩЕМ СРЕДНЕМ ОБРАЗОВАНИИ", "АГУЛЬНАЙ СЯРЭДНЯЙ АДУКАЦЫІ"],
                in: text
            )
            if hasCertificateWords {
                checks.append("Найдены признаки аттестата")
            } else {
                warnings.append("Не найдены надписи, характерные для аттестата.")
            }
            appendNameCheck(text: text, expected: expected, checks: &checks, warnings: &warnings)
            return result(
                likelyMatches: hasMinimumResolution && hasCertificateWords,
                confidence: score(
                    quality: hasMinimumResolution,
                    primaryEvidence: hasCertificateWords,
                    secondaryEvidence: !recognizedText.isEmpty,
                    confidence: averageOCRConfidence
                ),
                checks: checks,
                warnings: warnings
            )

        case .examCertificate:
            let hasExamWords = containsAny(
                ["СЕРТИФИКАТ", "ЦЭ", "ЦТ", "ЦЕНТРАЛИЗОВАННЫЙ ЭКЗАМЕН", "ЦЕНТРАЛИЗОВАННОЕ ТЕСТИРОВАНИЕ"],
                in: text
            )
            if hasExamWords {
                checks.append("Найдены признаки сертификата ЦЭ / ЦТ")
            } else {
                warnings.append("Не найдены признаки сертификата ЦЭ или ЦТ.")
            }
            appendNameCheck(text: text, expected: expected, checks: &checks, warnings: &warnings)
            return result(
                likelyMatches: hasMinimumResolution && hasExamWords,
                confidence: score(
                    quality: hasMinimumResolution,
                    primaryEvidence: hasExamWords,
                    secondaryEvidence: !recognizedText.isEmpty,
                    confidence: averageOCRConfidence
                ),
                checks: checks,
                warnings: warnings
            )

        case .portrait:
            if faceCount == 1 {
                checks.append("Обнаружено одно лицо")
            } else if faceCount == 0 {
                warnings.append("Лицо на фотографии не обнаружено.")
            } else {
                warnings.append("На фотографии должно быть только одно лицо.")
            }

            let portraitOrientation = pixelHeight > pixelWidth
            if portraitOrientation {
                checks.append("Вертикальная ориентация фотографии")
            } else {
                warnings.append("Для фото 3×4 выберите вертикальную фотографию.")
            }
            let confidence = min(
                1,
                (hasMinimumResolution ? 0.35 : 0)
                    + (faceCount == 1 ? 0.5 : 0)
                    + (portraitOrientation ? 0.15 : 0)
            )
            return result(
                likelyMatches: hasMinimumResolution && faceCount == 1 && portraitOrientation,
                confidence: confidence,
                checks: checks,
                warnings: warnings
            )

        case .other:
            if !recognizedText.isEmpty {
                checks.append("На изображении обнаружен текст")
            }
            warnings.append("Тип прочего документа требует ручной проверки.")
            return DocumentVerification(
                status: .needsReview,
                confidence: hasMinimumResolution ? 0.5 : 0.2,
                matchedChecks: checks,
                warnings: warnings,
                checkedAt: Date()
            )
        }
    }

    private func appendIdentityChecks(
        text: String,
        expected: ExpectedDocumentData,
        checks: inout [String],
        warnings: inout [String]
    ) {
        appendNameCheck(text: text, expected: expected, checks: &checks, warnings: &warnings)

        let normalizedNumber = normalizeCompact(expected.passportNumber)
        if !normalizedNumber.isEmpty && normalizeCompact(text).contains(normalizedNumber) {
            checks.append("Номер паспорта совпадает с профилем")
        } else if !normalizedNumber.isEmpty {
            warnings.append("Номер паспорта не удалось сопоставить с профилем.")
        }

        if let birthDate = expected.birthDate {
            let formats = [
                birthDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()),
                birthDate.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
            ]
            let compactText = normalizeCompact(text)
            if formats.map(normalizeCompact).contains(where: compactText.contains) {
                checks.append("Дата рождения совпадает с профилем")
            } else {
                warnings.append("Дату рождения не удалось сопоставить с профилем.")
            }
        }
    }

    private func appendNameCheck(
        text: String,
        expected: ExpectedDocumentData,
        checks: inout [String],
        warnings: inout [String]
    ) {
        let requiredNames = [expected.lastName, expected.firstName]
            .filter { !normalize($0).isEmpty }
        let matchedCount = requiredNames.filter { nameMatches($0, in: text) }.count

        if !requiredNames.isEmpty && matchedCount == requiredNames.count {
            checks.append("ФИО совпадает с профилем с учётом транслитерации")
        } else if !requiredNames.isEmpty {
            warnings.append("ФИО не удалось полностью сопоставить с профилем на кириллице или латинице.")
        }
    }

    private func nameMatches(_ name: String, in text: String) -> Bool {
        let compactText = normalizeCompact(text)
        return nameVariants(for: name).contains { variant in
            let compactVariant = normalizeCompact(variant)
            return compactVariant.count >= 2 && compactText.contains(compactVariant)
        }
    }

    private func nameVariants(for name: String) -> Set<String> {
        var variants: Set<String> = [normalize(name)]

        if let systemTransliteration = name.applyingTransform(.toLatin, reverse: false) {
            variants.insert(normalize(systemTransliteration))
        }

        variants.insert(transliterate(name, using: passportTransliteration))
        variants.insert(transliterate(name, using: commonTransliteration))
        return variants.filter { !$0.isEmpty }
    }

    private func transliterate(_ value: String, using table: [Character: String]) -> String {
        value.uppercased().map { character in
            table[character] ?? String(character)
        }.joined()
    }

    // Two variants cover the machine-readable passport spelling (I/IA/IU)
    // and common English spelling (Y/YA/YU) without changing profile data.
    private var passportTransliteration: [Character: String] {
        [
            "А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "Е": "E",
            "Ё": "IO", "Ж": "ZH", "З": "Z", "И": "I", "Й": "I", "К": "K",
            "Л": "L", "М": "M", "Н": "N", "О": "O", "П": "P", "Р": "R",
            "С": "S", "Т": "T", "У": "U", "Ф": "F", "Х": "KH", "Ц": "TS",
            "Ч": "CH", "Ш": "SH", "Щ": "SHCH", "Ъ": "", "Ы": "Y", "Ь": "",
            "Э": "E", "Ю": "IU", "Я": "IA", "І": "I", "Ў": "U"
        ]
    }

    private var commonTransliteration: [Character: String] {
        var table = passportTransliteration
        table["Ё"] = "YO"
        table["Й"] = "Y"
        table["Ю"] = "YU"
        table["Я"] = "YA"
        table["Г"] = "H"
        return table
    }

    private func result(
        likelyMatches: Bool,
        confidence: Double,
        checks: [String],
        warnings: [String]
    ) -> DocumentVerification {
        DocumentVerification(
            status: likelyMatches ? .likelyMatches : .needsReview,
            confidence: min(max(confidence, 0), 1),
            matchedChecks: checks,
            warnings: warnings,
            checkedAt: Date()
        )
    }

    private func score(
        quality: Bool,
        primaryEvidence: Bool,
        secondaryEvidence: Bool,
        confidence: Double
    ) -> Double {
        min(
            1,
            (quality ? 0.2 : 0)
                + (primaryEvidence ? 0.4 : 0)
                + (secondaryEvidence ? 0.2 : 0)
                + min(max(confidence, 0), 1) * 0.2
        )
    }

    private func containsAny(_ values: [String], in text: String) -> Bool {
        values.map(normalize).contains(where: text.contains)
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .uppercased()
            .replacingOccurrences(of: "Ё", with: "Е")
            .replacingOccurrences(of: "[^A-ZА-ЯІЎ0-9]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeCompact(_ value: String) -> String {
        normalize(value).replacingOccurrences(of: " ", with: "")
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
