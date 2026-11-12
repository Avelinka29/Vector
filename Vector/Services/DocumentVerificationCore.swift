import Foundation

struct ExpectedDocumentData: Sendable, Equatable {
    let firstName: String
    let lastName: String
    let patronymic: String
    let firstNameLatin: String?
    let lastNameLatin: String?
    let patronymicLatin: String?
    let birthDate: Date?
    let passportNumber: String
}

enum DocumentKind: String, Codable, CaseIterable, Identifiable {
    case passport
    case certificate
    case examCertificate
    case portrait
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .passport: "Паспорт"
        case .certificate: "Аттестат"
        case .examCertificate: "Сертификат ЦЭ / ЦТ"
        case .portrait: "Фото 3×4"
        case .other: "Другие документы"
        }
    }

    var subtitle: String {
        switch self {
        case .passport: "Разворот с фотографией"
        case .certificate: "Документ об образовании"
        case .examCertificate: "При наличии"
        case .portrait: "Фотография для документов"
        case .other: "Необязательно"
        }
    }

    var isRequired: Bool {
        false
    }

    var icon: String {
        switch self {
        case .passport: "person.text.rectangle"
        case .certificate: "doc.text"
        case .examCertificate: "checkmark.seal"
        case .portrait: "person.crop.rectangle"
        case .other: "paperclip"
        }
    }
}

enum DocumentVerificationStatus: String, Codable, Equatable {
    case checking
    case likelyMatches
    case needsReview
    case failed
}

struct DocumentVerification: Codable, Equatable {
    var status: DocumentVerificationStatus
    var confidence: Double
    var matchedChecks: [String]
    var warnings: [String]
    var checkedAt: Date?
}

struct DocumentVerificationEvaluator {
    func evaluate(
        kind: DocumentKind,
        recognizedText: String,
        averageOCRConfidence: Double,
        faceCount: Int,
        pixelWidth: Int,
        pixelHeight: Int,
        expected: ExpectedDocumentData
    ) -> DocumentVerification {
        // In a passport MRZ the issuing-country code is attached to the surname.
        let identityText = recognizedText.uppercased().replacingOccurrences(
            of: "\\bP<[A-Z]{3}", with: " ", options: .regularExpression
        )
        let text = normalize(identityText)
        let namesMatch = nameMatches(expected.firstName, latin: expected.firstNameLatin, in: text)
            && nameMatches(expected.lastName, latin: expected.lastNameLatin, in: text)
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
                likelyMatches: hasMinimumResolution && hasPassportWords && faceCount > 0
                    && namesMatch && warnings.isEmpty,
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
                likelyMatches: hasMinimumResolution && hasCertificateWords && namesMatch && warnings.isEmpty,
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
                likelyMatches: hasMinimumResolution && hasExamWords && namesMatch && warnings.isEmpty,
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
            // Numeric passport dates must not depend on the device's language.
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            let formats = ["ddMMyyyy", "yyyyMMdd"].map { format in
                formatter.dateFormat = format
                return formatter.string(from: birthDate)
            }
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
        let requiredNames = [
            (expected.lastName, expected.lastNameLatin),
            (expected.firstName, expected.firstNameLatin)
        ]
        let matchedCount = requiredNames.filter { cyrillic, latin in
            nameMatches(cyrillic, latin: latin, in: text)
        }.count

        if !requiredNames.isEmpty && matchedCount == requiredNames.count {
            checks.append("Имя и фамилия совпадают с профилем с учётом транслитерации")
        } else if !requiredNames.isEmpty {
            warnings.append("Имя и фамилию не удалось полностью сопоставить с профилем на кириллице или латинице.")
        }
    }

    private func nameMatches(_ name: String, latin: String?, in text: String) -> Bool {
        // Match complete OCR words, including '<'-separated MRZ names.
        // A substring match incorrectly accepted Анна inside Жанна.
        let paddedText = " " + normalize(text) + " "
        var variants = nameVariants(for: name)
        if let latin, !normalize(latin).isEmpty {
            variants.insert(normalize(latin))
        }
        return variants.contains { variant in
            let normalizedVariant = normalize(variant)
            return normalizedVariant.count >= 2
                && paddedText.contains(" " + normalizedVariant + " ")
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
