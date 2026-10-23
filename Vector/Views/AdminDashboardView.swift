import SwiftUI
import UniformTypeIdentifiers

struct AdminDashboardView: View {
    let user: AuthenticatedUser
    let onSignOut: () -> Void

    @State private var selection: AdminTab = .overview

    var body: some View {
        TabView(selection: $selection) {
            AdminOverviewView(openModeration: { selection = .moderation })
                .tag(AdminTab.overview)
                .tabItem { Label("Обзор", systemImage: "house") }

            AdminModerationView()
                .tag(AdminTab.moderation)
                .tabItem { Label("Проверки", systemImage: "doc.text") }

            AdminParticipantsView()
                .tag(AdminTab.participants)
                .tabItem { Label("Участники", systemImage: "star") }

            AdminAccessView(user: user, onSignOut: onSignOut)
                .tag(AdminTab.settings)
                .tabItem { Label("Настройки", systemImage: "person") }
        }
        .tint(.systemBlue01)
    }
}

private enum AdminTab: Hashable {
    case overview
    case moderation
    case participants
    case settings
}

private struct AdminOverviewView: View {
    @State private var model = AdminInstitutionsViewModel()
    let openModeration: () -> Void

    private var pendingCount: Int {
        model.institutions.filter { $0.requiresVerification == true }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AdminHeader(
                        title: "Обзор платформы",
                        subtitle: "Администратор · \(Date.now.formatted(date: .long, time: .omitted))"
                    )

                    HStack(spacing: 12) {
                        AdminMetricCard(value: "—", title: "Пользователей")
                        AdminMetricCard(value: "\(model.institutions.count)", title: "Учреждений")
                        AdminMetricCard(value: "—", title: "Компаний")
                    }

                    Button(action: openModeration) {
                        HStack {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("\(pendingCount) записей требуют проверки")
                                    .font(.headline)
                                    .foregroundStyle(.systemDarkBlue)
                                Text("Учреждения и сведения справочника")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.title3)
                                .foregroundStyle(.systemBlue01)
                        }
                        .padding(20)
                        .background(AdminPalette.warning, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)

                    AdminRegistrationsChart()

                    Text("Быстрые действия")
                        .font(.title2.bold())
                        .foregroundStyle(.systemDarkBlue)

                    Button(action: openModeration) {
                        AdminActionRow(
                            icon: "building.2",
                            title: "Модерация учреждений",
                            subtitle: "\(pendingCount) записей ожидают проверки"
                        )
                    }
                    .buttonStyle(.plain)

                    Label("Все сервисы работают штатно", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .background(.systemWhite)
            .toolbar(.hidden, for: .navigationBar)
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }
}

private struct AdminModerationView: View {
    @State private var model = AdminInstitutionsViewModel()
    @State private var organizationModel = OrganizationModerationViewModel()
    @State private var category = ModerationCategory.organizations

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AdminHeader(title: "Модерация", subtitle: "Проверка безопасности и достоверности")

                    Picker("Раздел проверки", selection: $category) {
                        ForEach(ModerationCategory.allCases) { category in
                            Text(category.title(count: count(for: category))).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    if organizationModel.isLoading && organizationModel.organizations.isEmpty {
                        ProgressView("Загрузка…")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if category == .organizations {
                        if let errorMessage = organizationModel.errorMessage {
                            AdminEmptyState(
                                icon: "wifi.exclamationmark",
                                title: "Не удалось загрузить заявки",
                                message: errorMessage
                            )
                        } else if organizationModel.pendingOrganizations.isEmpty {
                            AdminEmptyState(
                                icon: "checkmark.shield",
                                title: "Всё проверено",
                                message: "Новых заявок организаций пока нет."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(organizationModel.pendingOrganizations) { organization in
                                    NavigationLink {
                                        AdminOrganizationApplicationReviewView(
                                            organization: organization,
                                            onStatusChange: { status in
                                                try await organizationModel.setStatus(
                                                    status,
                                                    for: organization
                                                )
                                            }
                                        )
                                    } label: {
                                        AdminOrganizationApplicationCard(organization: organization)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else if category == .reports {
                        NavigationLink {
                            AdminReportReviewView()
                        } label: {
                            AdminActionRow(
                                icon: "exclamationmark.bubble",
                                title: "Обращение № 0142",
                                subtitle: "Жалоба на вакансию · Требует решения"
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        AdminEmptyState(
                            icon: "doc.text",
                            title: "Новых записей нет",
                            message: "Этот раздел появится после подключения соответствующих данных."
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Проверяйте данные перед подтверждением")
                            .font(.headline)
                            .foregroundStyle(.systemDarkBlue)
                        Text("После проверки организация получит доступ.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(AdminPalette.surface, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .background(.systemWhite)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                async let loadCatalog: Void = model.load()
                async let loadApplications: Void = organizationModel.load()
                _ = await (loadCatalog, loadApplications)
            }
            .refreshable {
                async let loadCatalog: Void = model.load()
                async let loadApplications: Void = organizationModel.load()
                _ = await (loadCatalog, loadApplications)
            }
        }
    }

    private func count(for category: ModerationCategory) -> Int {
        category == .organizations ? organizationModel.pendingOrganizations.count : 0
    }
}

private struct AdminReportReviewView: View {
    @State private var moderatorComment = ""
    @State private var resolutionMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AdminHeader(title: "Обращение № 0142", subtitle: "Жалоба на вакансию · Сегодня, 09:15")

                Text("Требует решения")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AdminPalette.warning, in: Capsule())

                VStack(alignment: .leading, spacing: 10) {
                    Text("Недостоверные условия стажировки")
                        .font(.title2.bold())
                        .foregroundStyle(.systemDarkBlue)
                    Text("Пользователь сообщил о несоответствии зарплаты в описании и на собеседовании.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    AdminDetailRow(icon: "briefcase", title: "Frontend-стажёр", subtitle: "ООО «Диджитал Групп»")
                    AdminDetailRow(icon: "person", title: "Автор обращения", subtitle: "Данные доступны после подключения обращений")
                }

                Text("Комментарий модератора")
                    .font(.title2.bold())
                    .foregroundStyle(.systemDarkBlue)

                TextEditor(text: $moderatorComment)
                    .frame(minHeight: 130)
                    .padding(14)
                    .scrollContentBackground(.hidden)
                    .background(AdminPalette.surface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(alignment: .topLeading) {
                        if moderatorComment.isEmpty {
                            Text("Добавьте основание решения…")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 19)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }
                    }

                if let resolutionMessage {
                    Text(resolutionMessage)
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                Button {
                    resolutionMessage = "Решение подготовлено. Отправка будет доступна после подключения обращений."
                } label: {
                    AdminPrimaryButtonLabel(title: "Скрыть вакансию и уведомить")
                }

                Button {
                    resolutionMessage = "Отклонение подготовлено. Отправка будет доступна после подключения обращений."
                } label: {
                    AdminOutlinedButtonLabel(title: "Отклонить жалобу")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(.systemWhite)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum ModerationCategory: String, CaseIterable, Identifiable {
    case organizations
    case documents
    case reports

    var id: String { rawValue }

    func title(count: Int) -> String {
        switch self {
        case .organizations: "Организации · \(count)"
        case .documents: "Документы · \(count)"
        case .reports: "Жалобы · \(count)"
        }
    }
}

private struct AdminOrganizationReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let institution: InstitutionRecord
    let model: AdminInstitutionsViewModel
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AdminHeader(title: "Проверка организации", subtitle: "Заявка № \(institution.id.prefix(8).uppercased())")

                VStack(alignment: .leading, spacing: 12) {
                    Text(institution.type == "university" ? "ЗАЯВКА УНИВЕРСИТЕТА" : "ЗАЯВКА УЧРЕЖДЕНИЯ")
                        .font(.caption)
                    Text(institution.name)
                        .font(.title.bold())
                    Text(institution.locality.isEmpty ? "Населённый пункт не указан" : institution.locality)
                    ProgressView(value: 0.74)
                        .tint(.white)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 12) {
                    AdminDetailRow(icon: "number", title: institution.officialID ?? "Идентификатор не указан", subtitle: "Официальный идентификатор")
                    AdminDetailRow(icon: "mappin", title: institution.address ?? institution.locality, subtitle: "Адрес организации")
                    AdminDetailRow(icon: "envelope", title: institution.admissionsEmail ?? "Контакт не указан", subtitle: "Контактное лицо")
                    AdminDetailRow(icon: "building.columns", title: institution.websiteURL ?? "Сайт не указан", subtitle: "Сайт организации")
                }

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                Button {
                    Task {
                        var approved = institution
                        approved.requiresVerification = false
                        approved.identityStatus = "verified"
                        if await model.save(approved) {
                            message = "Организация подтверждена."
                        }
                    }
                } label: {
                    AdminPrimaryButtonLabel(title: "Подтвердить организацию")
                }

                Button {
                    dismiss()
                } label: {
                    AdminOutlinedButtonLabel(title: "Вернуть на уточнение")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(.systemWhite)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdminParticipantsView: View {
    @State private var searchText = ""
    @State private var category = ParticipantCategory.users

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AdminHeader(title: "Участники платформы", subtitle: "Аккаунты и организации")

                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                        TextField("Имя, организация или email", text: $searchText)
                    }
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .background(AdminPalette.surface, in: RoundedRectangle(cornerRadius: 16))

                    Picker("Тип участника", selection: $category) {
                        ForEach(ParticipantCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    AdminEmptyState(
                        icon: "person.2",
                        title: "Список пока недоступен",
                        message: "Подключите административный источник аккаунтов, чтобы управлять участниками."
                    )

                    AdminActionRow(icon: "scope", title: "Расширенный поиск", subtitle: "Роль, статус и дата регистрации")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .background(.systemWhite)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private enum ParticipantCategory: String, CaseIterable, Identifiable {
    case users
    case companies
    case universities

    var id: String { rawValue }
    var title: String {
        switch self {
        case .users: "Пользователи"
        case .companies: "Компании"
        case .universities: "Вузы"
        }
    }
}

private struct AdminAccessView: View {
    let user: AuthenticatedUser
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AdminHeader(title: "Настройки доступа", subtitle: "Команда администраторов VECTOR")

                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "scope")
                            .font(.title2)
                            .foregroundStyle(.systemBlue01)
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Доступ под контролем")
                                .font(.title3.bold())
                                .foregroundStyle(.systemDarkBlue)
                            Text("Доступ защищён учётной записью администратора")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(AdminPalette.surface, in: RoundedRectangle(cornerRadius: 18))

                    Text("Команда платформы")
                        .font(.title2.bold())
                        .foregroundStyle(.systemDarkBlue)

                    AdminTeamCard(email: user.email)

                    NavigationLink {
                        InstitutionManagementView()
                    } label: {
                        AdminActionRow(icon: "building.columns", title: "Справочник учреждений", subtitle: "Импорт и редактирование данных")
                    }
                    .buttonStyle(.plain)

                    AdminActionRow(icon: "doc.text", title: "Журнал действий", subtitle: "Изменения ролей и решения модерации")

                    Button("Выйти из аккаунта", role: .destructive, action: onSignOut)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .background(.systemWhite)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private enum AdminPalette {
    static let surface = Color.systemGrey1.opacity(0.45)
    static let border = Color.secondary.opacity(0.18)
    static let warning = Color.orange.opacity(0.12)
}

private struct AdminHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("VECTOR / АДМИНИСТРАТОР")
                .font(.caption.bold())
                .foregroundStyle(.systemBlue01)
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.systemDarkBlue)
                Spacer(minLength: 8)
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(.systemBlue01)
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }
}

private struct AdminMetricCard: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(.systemDarkBlue)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AdminPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AdminRegistrationsChart: View {
    private let values: [CGFloat] = [0.18, 0.34, 0.27, 0.55, 0.43, 0.78, 0.70, 0.93]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Активность справочника")
                .font(.headline)
                .foregroundStyle(.systemDarkBlue)
            Text("Динамика наполнения")
                .font(.title.bold())
                .foregroundStyle(.systemDarkBlue)
            GeometryReader { proxy in
                Path { path in
                    for index in values.indices {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(values.count - 1)
                        let y = proxy.size.height * (1 - values[index])
                        index == values.startIndex ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(.systemBlue01, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 120)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.systemWhite)
                .stroke(AdminPalette.border, lineWidth: 1)
        )
    }
}

private struct AdminModerationCard: View {
    let institution: InstitutionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AdminIconBox(systemName: institution.type == "university" ? "building.columns" : "building.2")
                VStack(alignment: .leading, spacing: 4) {
                    Text(institution.name)
                        .font(.headline)
                        .foregroundStyle(.systemDarkBlue)
                    Text(institution.type == "university" ? "Учреждение высшего образования" : "Учреждение образования")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(institution.locality.isEmpty ? "Данные загружены" : institution.locality)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(institution.requiresVerification == true ? "На проверке" : "Просмотр")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AdminPalette.warning, in: Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.systemWhite)
                .stroke(AdminPalette.border, lineWidth: 1)
        )
    }
}

private struct AdminActionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            AdminIconBox(systemName: icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.systemWhite)
                .stroke(AdminPalette.border, lineWidth: 1)
        )
    }
}

private struct AdminDetailRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        AdminActionRow(icon: icon, title: title, subtitle: subtitle)
    }
}

private struct AdminIconBox: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(.systemBlue01)
            .frame(width: 44, height: 44)
            .background(Color.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct AdminEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            AdminIconBox(systemName: icon)
            Text(title)
                .font(.headline)
                .foregroundStyle(.systemDarkBlue)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(AdminPalette.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct AdminTeamCard: View {
    let email: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AdminIconBox(systemName: "person")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Администратор VECTOR")
                        .font(.headline)
                        .foregroundStyle(.systemDarkBlue)
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Полный доступ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Администратор")
                    .font(.caption.bold())
                    .foregroundStyle(.systemBlue01)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.systemBlue01.opacity(0.08), in: Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.systemWhite)
                .stroke(AdminPalette.border, lineWidth: 1)
        )
    }
}

private struct AdminPrimaryButtonLabel: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: "arrow.right")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AdminOutlinedButtonLabel: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: "arrow.right")
        }
        .foregroundStyle(.systemBlue01)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.systemBlue01, lineWidth: 1.5)
        )
    }
}

struct InstitutionManagementView: View {
    @State private var model = AdminInstitutionsViewModel()
    @State private var editingInstitution: InstitutionRecord?
    @State private var isShowingCatalogImporter = false

    var body: some View {
        List {
            if model.isLoading && model.institutions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if let importResultMessage = model.importResultMessage {
                Label(importResultMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if model.institutions.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "Учреждений пока нет",
                    systemImage: "building.columns",
                    description: Text("Добавьте первое учебное заведение.")
                )
            }

            ForEach(model.institutions) { institution in
                Button {
                    editingInstitution = institution
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(institution.name)
                            .font(.headline)
                            .foregroundStyle(.systemDarkBlue)
                        Text(institution.locality)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("Удалить", role: .destructive) {
                        Task { await model.delete(id: institution.id) }
                    }
                }
            }
        }
        .navigationTitle("Учебные заведения")
        .toolbar {
            Menu {
                Button {
                    isShowingCatalogImporter = true
                } label: {
                    Label("Импортировать JSON", systemImage: "square.and.arrow.down")
                }
                .disabled(model.isImportingCatalog)

                Button {
                    editingInstitution = InstitutionRecord()
                } label: {
                    Label("Добавить вручную", systemImage: "plus")
                }
            } label: {
                if model.isImportingCatalog {
                    ProgressView()
                } else {
                    Label("Действия", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editingInstitution) { institution in
            InstitutionEditorView(institution: institution) { updated in
                let saved = await model.save(updated)
                if saved {
                    editingInstitution = nil
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingCatalogImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await model.importCatalog(from: url) }
            case .failure(let error):
                model.errorMessage = UserFacingError.message(
                    for: error,
                    fallback: "Не удалось открыть выбранный файл. Попробуйте выбрать его ещё раз."
                )
            }
        }
        .task {
            await model.load()
        }
        .refreshable {
            await model.load()
        }
    }
}

struct InstitutionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var institution: InstitutionRecord
    let onSave: (InstitutionRecord) async -> Void

    init(
        institution: InstitutionRecord,
        onSave: @escaping (InstitutionRecord) async -> Void
    ) {
        _institution = State(initialValue: institution)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $institution.name)
                TextField("Тип", text: $institution.type)
                TextField("Населённый пункт", text: $institution.locality)
                TextField("ID региона", text: $institution.regionID)
                Toggle("Активно", isOn: $institution.isActive)
            }
            .navigationTitle("Учебное заведение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        Task { await onSave(institution) }
                    }
                    .disabled(
                        institution.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || institution.locality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}
