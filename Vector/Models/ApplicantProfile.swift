import Foundation

struct ApplicantProfile: Codable, Equatable {
    var personal = PersonalData()
    var contact = ContactData()
    var passport = PassportData()
    var address = AddressData()
    var education = EducationData()
    var institution = InstitutionData()
    var documents: [ProfileDocument] = DocumentKind.allCases.map { ProfileDocument(kind: $0) }
    var examResults: [ExamResult] = []
    var achievements: [Achievement] = AchievementCategory.allCases.map { Achievement(category: $0) }
    var additional = AdditionalData()

    var displayName: String {
        [personal.firstName, personal.patronymic].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var completionPercentage: Int {
        let checks = [
            !personal.lastName.isEmpty,
            !personal.firstName.isEmpty,
            personal.birthDate != nil,
            !contact.email.isEmpty,
            !contact.phone.isEmpty,
            !passport.seriesAndNumber.isEmpty,
            !passport.identificationNumber.isEmpty,
            !address.countryID.isEmpty,
            !address.regionID.isEmpty,
            !address.cityID.isEmpty,
            education.status != nil,
            !institution.name.isEmpty,
            !additional.citizenship.isEmpty
        ]
        return Int((Double(checks.filter { $0 }.count) / Double(checks.count)) * 100)
    }
}

struct PersonalData: Codable, Equatable {
    var lastName = ""
    var firstName = ""
    var patronymic = ""
    var lastNameLatin: String?
    var firstNameLatin: String?
    var patronymicLatin: String?
    var birthDate: Date?
}

struct ContactData: Codable, Equatable {
    var email = ""
    var phone = ""
    var reservePhone = ""
}

struct PassportData: Codable, Equatable {
    var seriesAndNumber = ""
    var identificationNumber = ""
    var issueDate: Date?
    var issuedBy = ""
}

struct AddressData: Codable, Equatable {
    var countryID = ""
    var regionID = ""
    var cityID = ""
    var street = ""
    var house = ""
    var apartment = ""

    private enum CodingKeys: String, CodingKey {
        case countryID = "countryId"
        case regionID = "regionId"
        case cityID = "cityId"
        case street
        case house
        case apartment
    }
}

enum EducationStatus: String, Codable, CaseIterable, Identifiable {
    case grade11
    case grade9
    case university
    case college

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grade11: "Выпускник школы (11 класс)"
        case .grade9: "Выпускник школы (9 класс)"
        case .university: "Студент вуза"
        case .college: "Учащийся колледжа"
        }
    }

    var icon: String {
        switch self {
        case .grade11, .grade9: "graduationcap"
        case .university: "building.columns"
        case .college: "books.vertical"
        }
    }

    var institutionLabel: String {
        switch self {
        case .grade11, .grade9: "Школа"
        case .university: "Университет"
        case .college: "Колледж"
        }
    }
}

struct EducationData: Codable, Equatable {
    var status: EducationStatus?
    var graduationYear: Int?
}

struct InstitutionData: Codable, Equatable {
    var name = ""
    var locality = ""
    var profileClass = ""
}

enum DocumentTransferStatus: String, Codable, Equatable {
    case notSelected
    case selected
    case uploading
    case uploaded
    case failed
}

struct ProfileDocument: Codable, Equatable, Identifiable {
    var kind: DocumentKind
    var fileName: String?
    var localURL: URL?
    var mimeType: String?
    var fileSize: Int?
    var selectedAt: Date?
    var verification: DocumentVerification?
    var status: DocumentTransferStatus = .notSelected
    var errorMessage: String?

    var id: DocumentKind { kind }
}

struct ExamResult: Codable, Equatable, Identifiable {
    var id = UUID()
    var subject = ""
    var score = ""
}

enum ExamRules {
    static let minimumScore = 0
    static let maximumScore = 100
}

enum AchievementCategory: String, Codable, CaseIterable, Identifiable {
    case olympiad
    case competition
    case sport
    case volunteering
    case science

    var id: String { rawValue }

    var title: String {
        switch self {
        case .olympiad: "Олимпиады"
        case .competition: "Конкурсы"
        case .sport: "Спортивные достижения"
        case .volunteering: "Волонтёрская деятельность"
        case .science: "Научные работы"
        }
    }

    var icon: String {
        switch self {
        case .olympiad: "medal"
        case .competition: "trophy"
        case .sport: "figure.run"
        case .volunteering: "heart"
        case .science: "atom"
        }
    }
}

struct Achievement: Codable, Equatable, Identifiable {
    var category: AchievementCategory
    var isIncluded = false
    var count = 1
    var details = ""
    var supportingFileName: String?
    var supportingFileURL: URL?

    var id: AchievementCategory { category }
}

struct AdditionalData: Codable, Equatable {
    var citizenship = ""
    var needsDormitory = false
    var targetEducation = false
    var preferredDirections = ""
    var preferredCities = ""
    var preferredEducationLevel = ""
    var preferredStudyForm = ""
    var fundingPreference = ""
    var willingToRelocate = false
    var comment = ""

    private enum CodingKeys: String, CodingKey {
        case citizenship
        case needsDormitory
        case targetEducation
        case preferredDirections
        case preferredCities
        case preferredEducationLevel
        case preferredStudyForm
        case fundingPreference
        case willingToRelocate
        case comment
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        citizenship = try container.decodeIfPresent(String.self, forKey: .citizenship) ?? ""
        needsDormitory = try container.decodeIfPresent(Bool.self, forKey: .needsDormitory) ?? false
        targetEducation = try container.decodeIfPresent(Bool.self, forKey: .targetEducation) ?? false
        preferredDirections = try container.decodeIfPresent(String.self, forKey: .preferredDirections) ?? ""
        preferredCities = try container.decodeIfPresent(String.self, forKey: .preferredCities) ?? ""
        preferredEducationLevel = try container.decodeIfPresent(String.self, forKey: .preferredEducationLevel) ?? ""
        preferredStudyForm = try container.decodeIfPresent(String.self, forKey: .preferredStudyForm) ?? ""
        fundingPreference = try container.decodeIfPresent(String.self, forKey: .fundingPreference) ?? ""
        willingToRelocate = try container.decodeIfPresent(Bool.self, forKey: .willingToRelocate) ?? false
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
    }

    var hasEducationPreferences: Bool {
        !preferredDirections.isEmpty
            || !preferredCities.isEmpty
            || !preferredEducationLevel.isEmpty
            || !preferredStudyForm.isEmpty
            || !fundingPreference.isEmpty
    }
}

struct InstitutionOption: Identifiable, Equatable {
    let id: String
    let name: String
    let locality: String
    let supportedStatuses: Set<EducationStatus>
}

// Учреждения для анкеты загружаются из серверного справочника.
