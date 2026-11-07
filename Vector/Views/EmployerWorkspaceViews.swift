import Observation
import SwiftUI

nonisolated struct EmployerVacancy: Codable, Identifiable, Sendable {
    let id: UUID
    let organizationId: UUID
    let title: String
    let description: String
    let city: String
    let employmentType: String
    let salaryFrom: Int?
    let salaryTo: Int?
    let status: String
    let expiresAt: String?
    let createdAt: Date
    let updatedAt: Date
    let responsesCount: Int
}

nonisolated struct EmployerResponse: Codable, Identifiable, Sendable {
    let id: UUID
    let vacancyId: UUID
    let applicantId: UUID
    let applicantEmail: String
    let vacancyTitle: String
    let coverLetter: String
    let status: String
    let employerComment: String
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct OrganizationMember: Codable, Identifiable, Sendable {
    let membershipId: UUID
    let userId: UUID
    let email: String
    let role: String
    let createdAt: Date

    var id: UUID { membershipId }
}

nonisolated struct VacancyDraft: Encodable, Sendable {
    var title = ""
    var description = ""
    var city = ""
    var employmentType = "Полная занятость"
    var salaryFrom: Int?
    var salaryTo: Int?
    var status = "published"
    var expiresAt: String?
}

actor EmployerWorkspaceService {
    private let api = BackendAPIClient.shared

    func vacancies() async throws -> [EmployerVacancy] {
        try await api.request("/api/v1/employer/vacancies", authorized: true)
    }

    func create(_ draft: VacancyDraft) async throws -> EmployerVacancy {
        try await api.request(
            "/api/v1/employer/vacancies",
            method: "POST",
            body: draft,
            authorized: true
        )
    }

    func delete(id: UUID) async throws {
        let _: EmptyResponse = try await api.request(
            "/api/v1/employer/vacancies/\(id)",
            method: "DELETE",
            authorized: true
        )
    }

    func responses() async throws -> [EmployerResponse] {
        try await api.request("/api/v1/employer/responses", authorized: true)
    }

    func updateResponse(id: UUID, status: String) async throws -> EmployerResponse {
        struct Body: Encodable, Sendable {
            let status: String
            let employerComment: String
        }
        return try await api.request(
            "/api/v1/employer/responses/\(id)",
            method: "PATCH",
            body: Body(status: status, employerComment: ""),
            authorized: true
        )
    }

    func members() async throws -> [OrganizationMember] {
        try await api.request("/api/v1/employer/members", authorized: true)
    }

    func invite(email: String, role: String) async throws -> OrganizationMember {
        struct Body: Encodable, Sendable { let email: String; let role: String }
        return try await api.request(
            "/api/v1/employer/members",
            method: "POST",
            body: Body(email: email, role: role),
            authorized: true
        )
    }
}

@MainActor @Observable
private final class EmployerWorkspaceModel {
    var vacancies: [EmployerVacancy] = []
    var responses: [EmployerResponse] = []
    var members: [OrganizationMember] = []
    var isLoading = false
    var errorMessage: String?
    private let service = EmployerWorkspaceService()

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedVacancies = service.vacancies()
            async let loadedResponses = service.responses()
            async let loadedMembers = service.members()
            (vacancies, responses, members) = try await (loadedVacancies, loadedResponses, loadedMembers)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(_ draft: VacancyDraft) async throws {
        vacancies.insert(try await service.create(draft), at: 0)
    }

    func delete(_ vacancy: EmployerVacancy) async {
        do {
            try await service.delete(id: vacancy.id)
            vacancies.removeAll { $0.id == vacancy.id }
        } catch { errorMessage = error.localizedDescription }
    }

    func setResponse(_ response: EmployerResponse, status: String) async {
        do {
            let updated = try await service.updateResponse(id: response.id, status: status)
            if let index = responses.firstIndex(where: { $0.id == response.id }) {
                responses[index] = updated
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func invite(email: String, role: String) async throws {
        members.append(try await service.invite(email: email, role: role))
    }
}

struct EmployerWorkspaceView: View {
    @State private var model = EmployerWorkspaceModel()
    @State private var showsNewVacancy = false
    @State private var showsInvite = false

    var body: some View {
        List {
            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red)
            }
            Section("Вакансии") {
                Button("Создать вакансию", systemImage: "plus.circle.fill") {
                    showsNewVacancy = true
                }
                ForEach(model.vacancies) { vacancy in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(vacancy.title).font(.headline)
                        Text("\(vacancy.city) · Откликов: \(vacancy.responsesCount)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Удалить", role: .destructive) {
                            Task { await model.delete(vacancy) }
                        }
                    }
                }
            }
            Section("Отклики") {
                if model.responses.isEmpty { Text("Новых откликов пока нет").foregroundStyle(.secondary) }
                ForEach(model.responses) { response in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(response.vacancyTitle).font(.headline)
                        Text(response.applicantEmail).foregroundStyle(.secondary)
                        if !response.coverLetter.isEmpty { Text(response.coverLetter).font(.subheadline) }
                        Menu("Статус: \(response.status)") {
                            ForEach(["reviewing", "invited", "rejected"], id: \.self) { status in
                                Button(status) { Task { await model.setResponse(response, status: status) } }
                            }
                        }
                    }
                }
            }
            Section("Сотрудники") {
                Button("Добавить сотрудника", systemImage: "person.badge.plus") { showsInvite = true }
                ForEach(model.members) { member in
                    LabeledContent(member.email, value: member.role)
                }
            }
        }
        .navigationTitle("Кабинет работодателя")
        .overlay { if model.isLoading { ProgressView() } }
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(isPresented: $showsNewVacancy) {
            NewVacancyView { draft in try await model.create(draft) }
        }
        .sheet(isPresented: $showsInvite) {
            InviteMemberView { email, role in try await model.invite(email: email, role: role) }
        }
    }
}

private struct NewVacancyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = VacancyDraft()
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSave: (VacancyDraft) async throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $draft.title)
                TextField("Город", text: $draft.city)
                TextField("Тип занятости", text: $draft.employmentType)
                TextField("Описание", text: $draft.description, axis: .vertical).lineLimit(4...8)
                TextField("Зарплата от", value: $draft.salaryFrom, format: .number).keyboardType(.numberPad)
                TextField("Зарплата до", value: $draft.salaryTo, format: .number).keyboardType(.numberPad)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Новая вакансия")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Опубликовать") {
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            do { try await onSave(draft); dismiss() }
                            catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .disabled(isSaving || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct InviteMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var role = "member"
    @State private var errorMessage: String?
    let onInvite: (String, String) async throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Email зарегистрированного сотрудника", text: $email)
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                Picker("Роль", selection: $role) {
                    Text("Сотрудник").tag("member")
                    Text("Менеджер").tag("manager")
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Добавить сотрудника")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        Task {
                            do { try await onInvite(email, role); dismiss() }
                            catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .disabled(!email.contains("@"))
                }
            }
        }
    }
}
