import Foundation
import Observation
import SwiftUI

struct OrganizationApplicationReview: Identifiable, Equatable {
    let application: ApplicationRecord
    let applicantEmail: String
    let profile: ApplicantProfile?

    var id: String { application.id }

    var applicantName: String {
        guard let profile else { return applicantEmail }
        let parts = [
            profile.personal.lastName,
            profile.personal.firstName,
            profile.personal.patronymic
        ].filter { !$0.isEmpty }
        return parts.isEmpty ? applicantEmail : parts.joined(separator: " ")
    }
}

nonisolated private struct OrganizationApplicationDTO: Decodable, Sendable {
    let id: UUID
    let applicantId: UUID
    let institutionId: String
    let specialtyId: String
    let institutionName: String
    let specialtyName: String
    let studyForm: String
    let fundingType: String
    let priority: Int
    let status: ApplicationStatus
    let history: [ApplicationStatusEvent]
    let createdAt: Date
    let updatedAt: Date
    let applicantEmail: String
    let applicantProfile: ApplicantProfile?

    @MainActor
    var review: OrganizationApplicationReview {
        var application = ApplicationRecord(
            id: id.uuidString.lowercased(),
            applicantID: applicantId.uuidString.lowercased(),
            institutionID: institutionId,
            institutionName: institutionName,
            specialtyID: specialtyId,
            specialtyName: specialtyName,
            studyForm: studyForm,
            fundingType: fundingType,
            priority: priority,
            status: status,
            createdAt: createdAt
        )
        application.history = history
        application.updatedAt = updatedAt
        return OrganizationApplicationReview(
            application: application,
            applicantEmail: applicantEmail,
            profile: applicantProfile
        )
    }
}

nonisolated private struct OrganizationStatusBody: Encodable, Sendable {
    let status: ApplicationStatus
    let comment: String?
}

@MainActor
struct OrganizationApplicationsService {
    private let api = BackendAPIClient.shared

    func fetch() async throws -> [OrganizationApplicationReview] {
        let response: [OrganizationApplicationDTO] = try await api.request(
            "/api/v1/applications/organization",
            authorized: true
        )
        return response.map(\.review)
    }

    func update(
        id: String,
        status: ApplicationStatus,
        comment: String?
    ) async throws -> OrganizationApplicationReview {
        let response: OrganizationApplicationDTO = try await api.request(
            "/api/v1/applications/organization/\(id)/status",
            method: "PATCH",
            body: OrganizationStatusBody(
                status: status,
                comment: comment?.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            authorized: true
        )
        return response.review
    }
}

@MainActor
@Observable
final class OrganizationApplicationsViewModel {
    var applications: [OrganizationApplicationReview] = []
    var isLoading = false
    var errorMessage: String?

    private let service = OrganizationApplicationsService()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await service.fetch()
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось загрузить заявления."
            )
        }
    }

    func update(
        id: String,
        status: ApplicationStatus,
        comment: String
    ) async throws {
        let updated = try await service.update(id: id, status: status, comment: comment)
        if let index = applications.firstIndex(where: { $0.id == id }) {
            applications[index] = updated
        }
    }
}

struct OrganizationApplicationsView: View {
    @State private var model = OrganizationApplicationsViewModel()

    var body: some View {
        Group {
            if model.isLoading && model.applications.isEmpty {
                ProgressView("Загрузка заявлений…")
            } else if model.applications.isEmpty {
                ContentUnavailableView {
                    Label("Заявлений пока нет", systemImage: "tray")
                } description: {
                    Text("Заявления абитуриентов появятся здесь после отправки.")
                }
            } else {
                List(model.applications) { review in
                    NavigationLink(value: review.id) {
                        OrganizationApplicationRow(
                            applicantName: review.applicantName,
                            specialtyName: review.application.specialtyName,
                            status: review.application.status,
                            submittedAt: review.application.createdAt
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Заявления")
        .navigationDestination(for: String.self) { id in
            if let review = model.applications.first(where: { $0.id == id }) {
                OrganizationApplicationDetailView(review: review) { status, comment in
                    try await model.update(id: id, status: status, comment: comment)
                }
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        .alert("Не удалось загрузить данные", isPresented: errorBinding) {
            Button("Повторить") { Task { await model.load() } }
            Button("Закрыть", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "Попробуйте ещё раз.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}

private struct OrganizationApplicationRow: View {
    let applicantName: String
    let specialtyName: String
    let status: ApplicationStatus
    let submittedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(applicantName)
                .font(.headline)
            Text(specialtyName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(submittedAt, format: .dateTime.day().month().year())
                Spacer()
                Text(status.title)
                    .font(.caption.bold())
                    .foregroundStyle(status == .rejected ? .red : .systemBlue01)
            }
            .font(.caption)
        }
        .padding(.vertical, 6)
    }
}

private struct OrganizationApplicationDetailView: View {
    let review: OrganizationApplicationReview
    let onDecision: (ApplicationStatus, String) async throws -> Void

    @State private var comment = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false

    var body: some View {
        Form {
            Section("Кандидат") {
                LabeledContent("Имя", value: review.applicantName)
                LabeledContent("Email", value: review.applicantEmail)
                if let profile = review.profile {
                    LabeledContent("Телефон", value: profile.contact.phone.isEmpty ? "Не указан" : profile.contact.phone)
                    LabeledContent("Профиль", value: "\(profile.completionPercentage)%")
                } else {
                    Text("Профиль ещё не заполнен")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Заявление") {
                LabeledContent("Специальность", value: review.application.specialtyName)
                LabeledContent("Форма", value: studyFormTitle)
                LabeledContent("Финансирование", value: fundingTitle)
                LabeledContent("Приоритет", value: "\(review.application.priority)")
                LabeledContent("Статус", value: review.application.status.title)
            }

            Section("Комментарий учреждения") {
                TextField("Основание решения", text: $comment, axis: .vertical)
                    .lineLimit(3...7)
            }

            Section {
                decisionButton("Документы на проверке", status: .documentsReview)
                decisionButton("Принять заявление", status: .accepted)
                decisionButton("Отклонить заявление", status: .rejected, destructive: true)
            }
        }
        .navigationTitle("Заявление")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: didSave)
        .alert("Не удалось сохранить решение", isPresented: errorBinding) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Попробуйте ещё раз.")
        }
    }

    private var studyFormTitle: String {
        review.application.studyForm == "fullTime" ? "Очная" : "Заочная"
    }

    private var fundingTitle: String {
        review.application.fundingType == "budget" ? "Бюджет" : "Платное"
    }

    private func decisionButton(
        _ title: String,
        status: ApplicationStatus,
        destructive: Bool = false
    ) -> some View {
        Button(title, role: destructive ? .destructive : nil) {
            Task { await save(status: status) }
        }
        .disabled(isSaving || (status == .rejected && comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }

    private func save(status: ApplicationStatus) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await onDecision(status, comment)
            didSave.toggle()
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось сохранить решение."
            )
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
