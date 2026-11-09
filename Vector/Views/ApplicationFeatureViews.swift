import Observation
import SwiftUI
import UniformTypeIdentifiers

nonisolated private struct ServerApplicationDocument: Codable, Identifiable, Sendable {
    let id: UUID
    let applicationId: UUID
    let kind: String
    let originalName: String
    let contentType: String
    let sizeBytes: Int
    let createdAt: Date
}

nonisolated private struct ServerApplicationComment: Codable, Identifiable, Sendable {
    let id: UUID
    let applicationId: UUID
    let authorId: UUID
    let text: String
    let isInternal: Bool
    let createdAt: Date
}

private actor ApplicationDetailsService {
    private let api = BackendAPIClient.shared

    func documents(applicationID: String) async throws -> [ServerApplicationDocument] {
        try await api.request("/api/v1/applications/\(applicationID)/documents", authorized: true)
    }

    func comments(applicationID: String) async throws -> [ServerApplicationComment] {
        try await api.request("/api/v1/applications/\(applicationID)/comments", authorized: true)
    }

    func addComment(applicationID: String, text: String) async throws -> ServerApplicationComment {
        struct Body: Encodable, Sendable { let text: String; let isInternal = false }
        return try await api.request(
            "/api/v1/applications/\(applicationID)/comments",
            method: "POST",
            body: Body(text: text),
            authorized: true
        )
    }

    func upload(applicationID: String, data: Data, fileName: String, contentType: String) async throws -> ServerApplicationDocument {
        try await api.upload(
            "/api/v1/applications/\(applicationID)/documents",
            fileData: data,
            fileName: fileName,
            contentType: contentType,
            fields: ["kind": "application"]
        )
    }
}

@MainActor @Observable
private final class ApplicationDetailsModel {
    var documents: [ServerApplicationDocument] = []
    var comments: [ServerApplicationComment] = []
    var errorMessage: String?
    var isWorking = false
    private let service = ApplicationDetailsService()

    func load(applicationID: String) async {
        do {
            async let documents = service.documents(applicationID: applicationID)
            async let comments = service.comments(applicationID: applicationID)
            (self.documents, self.comments) = try await (documents, comments)
        } catch { errorMessage = error.localizedDescription }
    }

    func addComment(applicationID: String, text: String) async throws {
        comments.append(try await service.addComment(applicationID: applicationID, text: text))
    }

    func upload(applicationID: String, url: URL) async {
        isWorking = true
        defer { isWorking = false }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            documents.append(try await service.upload(
                applicationID: applicationID,
                data: data,
                fileName: url.lastPathComponent,
                contentType: type
            ))
        } catch { errorMessage = error.localizedDescription }
    }
}

struct NewApplicationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var catalog = SpecialtiesViewModel()
    @State private var institutionType = "university"
    @State private var institutionID: String?
    @State private var specialtyID: String?
    @State private var studyForm = "fullTime"
    @State private var fundingType = "budget"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false
    let applicantID: String
    let onSubmitted: () -> Void

    init(
        applicantID: String,
        institutionID: String? = nil,
        specialtyID: String? = nil,
        onSubmitted: @escaping () -> Void = {}
    ) {
        self.applicantID = applicantID
        self.onSubmitted = onSubmitted
        _institutionID = State(initialValue: institutionID)
        _specialtyID = State(initialValue: specialtyID)
    }

    var body: some View {
        Form {
            Section {
                Picker("Тип учреждения", selection: $institutionType) {
                    Text("Университет").tag("university")
                    Text("Колледж").tag("college")
                }
                .pickerStyle(.inline)
            } header: {
                Text("Шаг 1 из 5")
            }

            Section("Учебное заведение") {
                Picker("Выберите учреждение", selection: $institutionID) {
                    Text("Не выбрано").tag(String?.none)
                    ForEach(
                        catalog.institutions.filter { $0.type == institutionType }
                    ) { institution in
                        Text(institution.name).tag(Optional(institution.id))
                    }
                }
            }

            Section("Специальность") {
                Picker("Выберите специальность", selection: $specialtyID) {
                    Text("Не выбрано").tag(String?.none)
                    ForEach(
                        catalog.specialties.filter { specialty in
                            catalog.links.contains {
                                $0.institutionID == institutionID && $0.specialtyID == specialty.id
                            }
                        }
                    ) { specialty in
                        Text(specialty.name).tag(Optional(specialty.id))
                    }
                }
                .disabled(institutionID == nil)
            }

            Section("Форма обучения") {
                Picker("Форма обучения", selection: $studyForm) {
                    Text("Очная").tag("fullTime")
                    Text("Заочная").tag("partTime")
                }
            }

            Section("Финансирование") {
                Picker("Финансирование", selection: $fundingType) {
                    Text("Бюджет").tag("budget")
                    Text("Платное").tag("paid")
                }
                .pickerStyle(.segmented)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Отправить заявление")
                    }
                }
                    .frame(maxWidth: .infinity)
                    .disabled(institutionID == nil || specialtyID == nil || applicantID.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("Новое заявление")
        .navigationBarTitleDisplayMode(.inline)
        .task { await catalog.load() }
        .onChange(of: institutionType) {
            institutionID = nil
            specialtyID = nil
        }
        .onChange(of: institutionID) {
            specialtyID = nil
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") { dismiss() }
            }
        }
        .sensoryFeedback(.success, trigger: didSubmit)
    }

    private func submit() async {
        guard
            let institution = catalog.institutions.first(where: { $0.id == institutionID }),
            let specialty = catalog.specialties.first(where: { $0.id == specialtyID })
        else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let model = ApplicationsViewModel(applicantID: applicantID)
            try await model.create(
                institution: institution,
                specialty: specialty,
                studyForm: studyForm,
                fundingType: fundingType
            )
            didSubmit = true
            onSubmitted()
            dismiss()
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось отправить заявление. Попробуйте ещё раз."
            )
        }
    }
}

struct ApplicationCard: View {
    let application: ApplicationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(.systemBlue01)
                    .frame(width: 44, height: 44)
                    .background(Color.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(application.institutionName)
                        .font(.headline)
                        .foregroundStyle(.systemDarkBlue)
                    Text(application.specialtyName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("\(fundingTitle) · \(studyFormTitle) · Приоритет \(application.priority)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(application.status.title)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(statusColor.opacity(0.1), in: Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.systemWhite)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private var fundingTitle: String { application.fundingType == "budget" ? "Бюджет" : "Платное" }
    private var studyFormTitle: String { application.studyForm == "fullTime" ? "Очная" : "Заочная" }
    private var statusColor: Color {
        switch application.status {
        case .accepted: .green
        case .rejected: .red
        case .draft: .secondary
        case .submitted, .documentsReview: .orange
        }
    }
}

struct ApplicationStatusView: View {
    let application: ApplicationRecord
    @State private var details = ApplicationDetailsModel()
    @State private var comment = ""
    @State private var showsFileImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Статус заявления")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.systemDarkBlue)
                    Text("№ \(application.id.prefix(10).uppercased()) · \(application.institutionName)")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(application.specialtyName.uppercased())
                        .font(.caption)
                    Text(application.status.title)
                        .font(.title.bold())
                    Text(statusDescription)
                        .font(.subheadline)
                    ProgressView(value: progress)
                        .tint(.white)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 20))

                Text("История заявления")
                    .font(.title2.bold())
                    .foregroundStyle(.systemDarkBlue)

                VStack(spacing: 0) {
                    ForEach(Array(application.history.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(Color.systemBlue01)
                                    .frame(width: 18, height: 18)
                                if index < application.history.count - 1 {
                                    Rectangle()
                                        .fill(Color.systemBlue01.opacity(0.18))
                                        .frame(width: 2, height: 54)
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.headline)
                                    .foregroundStyle(.systemDarkBlue)
                                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let details = event.details {
                                    Text(details).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }

                if let deadline = application.submissionDeadline {
                    Label("Предоставить документы до \(deadline)", systemImage: "calendar.badge.exclamationmark")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Документы").font(.title2.bold())
                        Spacer()
                        Button("Добавить", systemImage: "paperclip") { showsFileImporter = true }
                    }
                    if details.documents.isEmpty {
                        Text("Файлы ещё не загружены").foregroundStyle(.secondary)
                    }
                    ForEach(details.documents) { document in
                        Label("\(document.originalName) · \(ByteCountFormatter.string(fromByteCount: Int64(document.sizeBytes), countStyle: .file))", systemImage: "doc")
                            .font(.subheadline)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Комментарии").font(.title2.bold())
                    ForEach(details.comments) { item in
                        Text(item.text)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.systemBlue01.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }
                    HStack {
                        TextField("Написать комментарий", text: $comment, axis: .vertical)
                        Button("Отправить") {
                            let value = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !value.isEmpty else { return }
                            Task {
                                do { try await details.addComment(applicationID: application.id, text: value); comment = "" }
                                catch { details.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                }

                if let error = details.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(24)
        }
        .background(.systemWhite)
        .navigationBarTitleDisplayMode(.inline)
        .task { await details.load(applicationID: application.id) }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.pdf, .jpeg, .png, .heic],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await details.upload(applicationID: application.id, url: url) }
        }
    }

    private var progress: Double {
        switch application.status {
        case .draft: 0.1
        case .submitted: 0.35
        case .documentsReview: 0.65
        case .accepted, .rejected: 1
        }
    }

    private var statusDescription: String {
        switch application.status {
        case .draft: "Завершите заполнение и отправьте заявление."
        case .submitted: "Заявление передано на рассмотрение."
        case .documentsReview: "Обычно проверка занимает до двух рабочих дней."
        case .accepted: "Учреждение подтвердило ваше заявление."
        case .rejected: "Откройте историю, чтобы узнать причину решения."
        }
    }
}

struct SpecialtyDetailsView: View {
    let specialty: SpecialtyRecord
    let institution: InstitutionRecord?
    let applicantID: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("VECTOR / АБИТУРИЕНТ")
                        .font(.caption.bold())
                        .foregroundStyle(.systemBlue01)
                    Text(specialty.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.systemDarkBlue)
                    Text(institution?.name ?? "Учреждение не указано")
                        .foregroundStyle(.secondary)
                }

                if specialty.requiresVerification == true {
                    Label("Сведения требуют проверки", systemImage: "exclamationmark.triangle")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1), in: Capsule())
                }

                HStack(spacing: 12) {
                    SpecialtyMetric(value: specialty.code.isEmpty ? "—" : specialty.code, title: "Код")
                    SpecialtyMetric(value: specialty.educationLevel ?? "—", title: "Уровень")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("О программе")
                        .font(.title2.bold())
                        .foregroundStyle(.systemDarkBlue)
                    if let qualification = specialty.qualification, !qualification.isEmpty {
                        LabeledContent("Квалификация", value: qualification)
                    }
                    LabeledContent(
                        "Формы обучения",
                        value: specialty.studyForms.isEmpty ? "Не указаны" : specialty.studyForms.formatted()
                    )
                    if let verifiedAt = specialty.lastVerifiedAt {
                        LabeledContent("Источник проверен", value: verifiedAt.formatted(date: .numeric, time: .omitted))
                    }
                }

                if let url = URL(string: specialty.sourceURL), !specialty.sourceURL.isEmpty {
                    Link(destination: url) {
                        Label("Открыть официальный источник", systemImage: "arrow.up.right.square")
                    }
                }

                if let institution, !applicantID.isEmpty {
                    NavigationLink {
                        NewApplicationView(
                            applicantID: applicantID,
                            institutionID: institution.id,
                            specialtyID: specialty.id
                        )
                    } label: {
                        HStack {
                            Text("Подать заявление").font(.headline)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .simultaneousGesture(TapGesture().onEnded { _ = institution })
                }
            }
            .padding(24)
        }
        .background(.systemWhite)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SpecialtyMetric: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.headline).foregroundStyle(.systemDarkBlue).lineLimit(2)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(16)
        .background(Color.systemGrey1.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PrioritiesView: View {
    @State private var model: ApplicationsViewModel
    @State private var isSaving = false
    @State private var didSave = false

    init(applicantID: String) {
        _model = State(initialValue: ApplicationsViewModel(applicantID: applicantID))
    }

    var body: some View {
        Group {
            if model.isLoading && model.applications.isEmpty {
                ProgressView("Загрузка…")
            } else if model.applications.isEmpty {
                ContentUnavailableView {
                    Label("Приоритеты не выбраны", systemImage: "list.number")
                } description: {
                    Text("Сначала отправьте хотя бы одно заявление.")
                }
            } else {
                List {
                    ForEach(model.applications) { application in
                        HStack {
                            Text("\(application.priority)")
                                .font(.headline)
                                .foregroundStyle(.systemBlue01)
                                .frame(width: 28)
                            VStack(alignment: .leading) {
                                Text(application.specialtyName).font(.headline)
                                Text(application.institutionName).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove(perform: model.move)
                }
                .toolbar {
                    EditButton()
                    Button(isSaving ? "Сохранение…" : "Сохранить") {
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            do {
                                try await model.savePriorities()
                                didSave.toggle()
                            } catch {
                                model.errorMessage = "Не удалось сохранить приоритеты."
                            }
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle("Приоритеты")
        .task { await model.load() }
        .sensoryFeedback(.success, trigger: didSave)
    }
}

struct AnalyticsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Аналитика пока недоступна", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Проходные баллы и конкурс появятся после подключения официальных данных приёмных кампаний.")
        }
        .navigationTitle("Аналитика")
    }
}

struct NotificationsView: View {
    @State private var model = NotificationsModel()

    var body: some View {
        Group {
            if model.isLoading && model.items.isEmpty {
                ProgressView("Загружаем уведомления…")
            } else if model.items.isEmpty {
                ContentUnavailableView {
                    Label("Уведомлений пока нет", systemImage: "bell")
                } description: {
                    Text("Здесь появятся изменения статусов заявлений и важные сообщения.")
                }
            } else {
                List(model.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.title).font(.headline)
                            Spacer()
                            if !item.isRead {
                                Circle().fill(Color.systemBlue01).frame(width: 8, height: 8)
                            }
                        }
                        Text(item.body).font(.subheadline).foregroundStyle(.secondary)
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await model.markRead(item) } }
                }
                .refreshable { await model.load() }
            }
        }
        .navigationTitle("Уведомления")
        .task { await model.load() }
        .alert("Не удалось обновить уведомления", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Закрыть", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .toolbar {
            Button("Обновить", systemImage: "arrow.clockwise") {
                Task { await model.load() }
            }
            .disabled(model.isLoading)
            if model.items.contains(where: { !$0.isRead }) {
                Button("Прочитать все") { Task { await model.markAllRead() } }
            }
        }
    }
}

nonisolated private struct BackendNotification: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let eventType: String
    let entityId: String
    var isRead: Bool
    let deliveredAt: Date?
    let createdAt: Date
}

@MainActor @Observable
private final class NotificationsModel {
    var items: [BackendNotification] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await BackendAPIClient.shared.request(
                "/api/v1/notifications",
                authorized: true
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ item: BackendNotification) async {
        guard !item.isRead else { return }
        do {
            let updated: BackendNotification = try await BackendAPIClient.shared.request(
                "/api/v1/notifications/\(item.id)/read",
                method: "PATCH",
                authorized: true
            )
            if let index = items.firstIndex(where: { $0.id == updated.id }) { items[index] = updated }
        } catch { errorMessage = error.localizedDescription }
    }

    func markAllRead() async {
        do {
            let _: EmptyResponse = try await BackendAPIClient.shared.request(
                "/api/v1/notifications/read-all",
                method: "POST",
                authorized: true
            )
            for index in items.indices { items[index].isRead = true }
        } catch { errorMessage = error.localizedDescription }
    }
}
