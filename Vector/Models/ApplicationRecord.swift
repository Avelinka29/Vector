import Foundation

enum ApplicationStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case submitted
    case documentsReview
    case accepted
    case rejected

    var title: String {
        switch self {
        case .draft: "Черновик"
        case .submitted: "Отправлено"
        case .documentsReview: "Документы на проверке"
        case .accepted: "Принято"
        case .rejected: "Отклонено"
        }
    }
}

struct ApplicationStatusEvent: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var status: ApplicationStatus
    var title: String
    var details: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        status: ApplicationStatus,
        title: String,
        details: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.status = status
        self.title = title
        self.details = details
        self.createdAt = createdAt
    }
}

struct ApplicationRecord: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var applicantID: String
    var institutionID: String
    var institutionName: String
    var specialtyID: String
    var specialtyName: String
    var studyForm: String
    var fundingType: String
    var priority: Int
    var status: ApplicationStatus
    var history: [ApplicationStatusEvent]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        applicantID: String,
        institutionID: String,
        institutionName: String,
        specialtyID: String,
        specialtyName: String,
        studyForm: String,
        fundingType: String = "budget",
        priority: Int = 1,
        status: ApplicationStatus = .submitted,
        createdAt: Date = .now
    ) {
        self.id = id
        self.applicantID = applicantID
        self.institutionID = institutionID
        self.institutionName = institutionName
        self.specialtyID = specialtyID
        self.specialtyName = specialtyName
        self.studyForm = studyForm
        self.fundingType = fundingType
        self.priority = priority
        self.status = status
        self.history = [
            ApplicationStatusEvent(
                status: status,
                title: status == .draft ? "Черновик создан" : "Заявление отправлено"
            )
        ]
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
