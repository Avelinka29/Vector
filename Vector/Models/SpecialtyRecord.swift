import Foundation

struct SpecialtyRecord: Codable, Equatable, Identifiable {
    var id: String
    var institutionID: String
    var name: String
    var code: String
    var qualification: String?
    var educationLevel: String?
    var studyForms: [String]
    var sourceURL: String
    var imageURL: String?
    var imageSourceURL: String?
    var faculty: String?
    var duration: Int?
    var budgetPlaces: Int?
    var paidPlaces: Int?
    var descriptionText: String?
    var lastVerifiedAt: Date?
    var requiresVerification: Bool?
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        institutionID: String = "",
        name: String = "",
        code: String = "",
        qualification: String? = nil,
        educationLevel: String? = nil,
        studyForms: [String] = [],
        sourceURL: String = "",
        lastVerifiedAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.institutionID = institutionID
        self.name = name
        self.code = code
        self.qualification = qualification
        self.educationLevel = educationLevel
        self.studyForms = studyForms
        self.sourceURL = sourceURL
        self.imageURL = nil
        self.imageSourceURL = nil
        self.faculty = nil
        self.duration = nil
        self.budgetPlaces = nil
        self.paidPlaces = nil
        self.descriptionText = nil
        self.lastVerifiedAt = lastVerifiedAt
        self.requiresVerification = nil
        self.isActive = isActive
    }
}
