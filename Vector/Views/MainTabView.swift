import SwiftUI

struct MainTabView: View {
    let userID: String
    let profile: ApplicantProfile?
    let profileStatus: ProfileStatus
    let onEditProfile: () -> Void
    let onEditDocuments: () -> Void
    let onSignOut: () -> Void
    let onDeleteAccount: (String) async throws -> Void

    init(
        userID: String = "",
        profile: ApplicantProfile? = nil,
        profileStatus: ProfileStatus = .notStarted,
        onEditProfile: @escaping () -> Void = {},
        onEditDocuments: @escaping () -> Void = {},
        onSignOut: @escaping () -> Void = {},
        onDeleteAccount: @escaping (String) async throws -> Void = { _ in }
    ) {
        self.userID = userID
        self.profile = profile
        self.profileStatus = profileStatus
        self.onEditProfile = onEditProfile
        self.onEditDocuments = onEditDocuments
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
    }

    var body: some View {
        TabView {
            Tab("Главная", systemImage: "house") {
                NavigationStack {
                    HomeView(
                        profile: profile,
                        profileStatus: profileStatus,
                        onEditProfile: onEditProfile
                    )
                }
            }

            Tab("Заявления", systemImage: "doc.text") {
                NavigationStack {
                    ApplicationsView(applicantID: userID)
                }
            }

            Tab("Возможности", systemImage: "star") {
                NavigationStack {
                    OpportunitiesView(applicantID: userID)
                }
            }

            Tab("Профиль", systemImage: "person") {
                NavigationStack {
                    ProfileView(
                        profile: profile,
                        profileStatus: profileStatus,
                        onEditProfile: onEditProfile,
                        onEditDocuments: onEditDocuments,
                        onSignOut: onSignOut,
                        userID: userID,
                        onDeleteAccount: onDeleteAccount
                    )
                }
            }
        }
        .tint(.systemBlue01)
    }
}

struct HomeView: View {
    let profile: ApplicantProfile?
    let profileStatus: ProfileStatus
    let onEditProfile: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HomeGreeting(name: profile?.personal.firstName ?? "")
                ProfileCompletionCard(percentage: profile?.completionPercentage ?? 0)
                if profileStatus != .complete {
                    Button(
                        profileStatus == .inProgress
                            ? "Продолжить заполнение профиля"
                            : "Заполнить профиль",
                        action: onEditProfile
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
                }
                Text("Мои заявления")
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                HomeApplicationsCard()
                Text("Найти")
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                HomeNavigationSection()
            }
            .padding(20)
        }
        .background(Color.systemBlue01.opacity(0.035))
//        .navigationTitle("Vector")
    }
}

struct HomeGreeting: View {
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("VECTOR / АБИТУРИЕНТ")
                .font(.caption.bold())
                .foregroundStyle(.systemBlue01)
            HStack(alignment: .firstTextBaseline) {
                Text(name.isEmpty ? "Добро пожаловать!" : "Привет, \(name)!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.systemDarkBlue)
                Spacer()
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(.systemBlue01)
            }
            Text("Твоё будущее начинается здесь")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }
}

struct ProfileCompletionCard: View {
    let percentage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ЦИФРОВОЙ ПРОФИЛЬ")
                        .font(.caption)
                        .opacity(0.85)
                    Text("Ты готова на \(percentage)%")
                        .font(.title.bold())
                    Text("Добавь достижения — выделись среди других")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }

            ProgressView(value: Double(percentage), total: 100)
                .tint(.white)

        }
        .padding(22)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [.systemBlue01, .systemBlue01.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(color: .systemBlue01.opacity(0.2), radius: 12, y: 6)
    }
}

private struct HomeQuickAction: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
            Text(title)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HomeNavigationSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Начните поиск")
                .font(.title2.bold())
                .foregroundStyle(.systemDarkBlue)

            NavigationLink {
                InstitutionsSearchView()
            } label: {
                HomeFeatureCard(
                    title: "Учебные заведения",
                    subtitle: "Университеты и колледжи Беларуси",
                    icon: "building.columns"
                )
            }

            NavigationLink {
                SpecialtiesSearchView()
            } label: {
                HomeFeatureCard(
                    title: "Специальности",
                    subtitle: "Поиск направлений подготовки",
                    icon: "book.closed"
                )
            }
        }
        .buttonStyle(.plain)
    }
}

struct HomeFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.systemGrey1.opacity(0.35))
        }
    }
}

struct HomeApplicationsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Мои заявления", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(.systemDarkBlue)
            Text("Здесь появятся ваши заявления после подключения приёмных кампаний.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct CatalogView: View {
    var body: some View {
        List {
            NavigationLink {
                InstitutionsSearchView()
            } label: {
                Label("Учебные заведения", systemImage: "building.columns")
            }
            NavigationLink {
                SpecialtiesSearchView()
            } label: {
                Label("Специальности", systemImage: "book.closed")
            }
        }
        .navigationTitle("Поиск")
    }
}

struct EducationCatalogItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

struct InstitutionsSearchView: View {
    @State private var model = InstitutionsViewModel()

    var body: some View {
        Group {
            if model.isLoading && model.institutions.isEmpty {
                ProgressView("Загружаем учебные заведения…")
            } else if let errorMessage = model.errorMessage, model.institutions.isEmpty {
                ContentUnavailableView {
                    Label("Не удалось загрузить данные", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Повторить") {
                        Task { await model.load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.systemBlue01)
                }
            } else if model.filteredInstitutions.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                List(model.filteredInstitutions) { institution in
                    NavigationLink {
                        InstitutionDetailsView(institution: institution)
                    } label: {
                        InstitutionRow(institution: institution)
                    }
                }
                .listStyle(.plain)
                .refreshable { await model.load() }
            }
        }
        .navigationTitle("Учебные заведения")
        .searchable(text: $model.searchText, prompt: "Название или город")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Город", selection: $model.selectedCity) {
                        Text("Все города").tag(String?.none)
                        ForEach(model.cities, id: \.self) { city in
                            Text(city).tag(Optional(city))
                        }
                    }
                    Picker("Регион", selection: $model.selectedRegionID) {
                        Text("Все регионы").tag(String?.none)
                        ForEach(model.regionIDs, id: \.self) { regionID in
                            Text(regionID).tag(Optional(regionID))
                        }
                    }
                    Picker("Тип", selection: $model.selectedType) {
                        Text("Все типы").tag(String?.none)
                        ForEach(model.types, id: \.self) { type in
                            Text(institutionTypeTitle(type)).tag(Optional(type))
                        }
                    }
                    Picker("Уровень", selection: $model.selectedEducationLevel) {
                        Text("Все уровни").tag(String?.none)
                        ForEach(model.educationLevels, id: \.self) { level in
                            Text(level).tag(Optional(level))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { await model.load() }
    }

    private func institutionTypeTitle(_ type: String) -> String {
        type == "college" ? "Колледж" : "Университет"
    }
}

private struct InstitutionRow: View {
    let institution: InstitutionRecord

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: institution.type == "college" ? "building.2" : "building.columns")
                .foregroundStyle(.systemBlue01)
                .frame(width: 42, height: 42)
                .background(.systemBlue01.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(institution.name)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                Text("\(institution.locality.isEmpty ? "Город не указан" : institution.locality) • \(institution.type == "college" ? "Колледж" : "Университет")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if institution.requiresVerification == true {
                    Label("Требует проверки", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

private struct InstitutionDetailsView: View {
    let institution: InstitutionRecord

    var body: some View {
        List {
            Section {
                Label(institution.locality, systemImage: "mappin.and.ellipse")
                if let address = institution.address, !address.isEmpty {
                    Label(address, systemImage: "map")
                }
            }

            if institution.websiteURL != nil || institution.admissionsURL != nil || institution.sourceURL != nil {
                Section("Официальные ссылки") {
                    if let website = validURL(institution.websiteURL) {
                        Link("Сайт учреждения", destination: website)
                    }
                    if let admissions = validURL(institution.admissionsURL) {
                        Link("Приёмная комиссия", destination: admissions)
                    }
                    if let source = validURL(institution.sourceURL) {
                        Link("Источник данных", destination: source)
                    }
                }
            }

            if institution.admissionsPhone != nil || institution.admissionsEmail != nil {
                Section("Приёмная комиссия") {
                    if let phone = institution.admissionsPhone, !phone.isEmpty {
                        LabeledContent("Телефон", value: phone)
                    }
                    if let email = institution.admissionsEmail, !email.isEmpty {
                        LabeledContent("Email", value: email)
                    }
                }
            }

            Section {
                NavigationLink {
                    InstitutionSpecialtiesView(
                        institutionID: institution.id,
                        institutionName: institution.name
                    )
                } label: {
                    Label("Специальности учреждения", systemImage: "book.closed")
                }
            }

            if let date = institution.lastVerifiedAt {
                Section("Статус данных") {
                    LabeledContent("Источник получен", value: date.formatted(date: .numeric, time: .omitted))
                    if institution.requiresVerification == true {
                        Label(
                            "Запись получена из неполной выгрузки и требует сверки с официальным реестром.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle(institution.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func validURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value),
              let scheme = url.scheme, ["https", "http"].contains(scheme) else {
            return nil
        }
        return url
    }
}

private struct InstitutionSpecialtiesView: View {
    let institutionID: String
    let institutionName: String
    @State private var model = SpecialtiesViewModel()

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView("Загружаем специальности…")
            } else if let errorMessage = model.errorMessage {
                ContentUnavailableView(
                    "Не удалось загрузить данные",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if model.visibleSpecialties.isEmpty {
                ContentUnavailableView(
                    "Специальности не опубликованы",
                    systemImage: "book.closed",
                    description: Text("Для этого учреждения сведения пока отсутствуют.")
                )
            } else {
                List(model.visibleSpecialties) { specialty in
                    SpecialtyRow(specialty: specialty, institutionName: institutionName)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Специальности")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(institutionID: institutionID) }
    }
}

struct SpecialtiesSearchView: View {
    @State private var model = SpecialtiesViewModel()
    let applicantID: String

    init(applicantID: String = "") {
        self.applicantID = applicantID
    }

    var body: some View {
        Group {
            if model.isLoading && model.specialties.isEmpty {
                ProgressView("Загружаем специальности…")
            } else if let errorMessage = model.errorMessage, model.specialties.isEmpty {
                ContentUnavailableView {
                    Label("Не удалось загрузить данные", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Повторить") { Task { await model.load() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.systemBlue01)
                }
            } else if model.visibleSpecialties.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                List(model.visibleSpecialties) { specialty in
                    NavigationLink {
                        SpecialtyDetailsView(
                            specialty: specialty,
                            institution: model.institutions(for: specialty.id).first,
                            applicantID: applicantID
                        )
                    } label: {
                        SpecialtyRow(
                            specialty: specialty,
                            institutionName: model.institutionNames(for: specialty.id)
                        )
                    }
                }
                .listStyle(.plain)
                .refreshable { await model.load() }
            }
        }
        .navigationTitle("Специальности")
        .searchable(text: $model.searchText, prompt: "Название, код или учреждение")
        .toolbar {
            Menu {
                Picker("Учреждение", selection: $model.selectedInstitutionID) {
                    Text("Все учреждения").tag(String?.none)
                    ForEach(model.institutions) { institution in
                        Text(institution.name).tag(Optional(institution.id))
                    }
                }
                Picker("Уровень", selection: $model.selectedEducationLevel) {
                    Text("Все уровни").tag(String?.none)
                    ForEach(model.educationLevels, id: \.self) { level in
                        Text(level).tag(Optional(level))
                    }
                }
                Picker("Форма обучения", selection: $model.selectedStudyForm) {
                    Text("Все формы").tag(String?.none)
                    ForEach(model.studyForms, id: \.self) { form in
                        Text(form).tag(Optional(form))
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
        .task { await model.load() }
    }
}

private struct SpecialtyRow: View {
    let specialty: SpecialtyRecord
    let institutionName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(specialty.name)
                .font(.headline)
                .foregroundStyle(.systemDarkBlue)
            if !specialty.code.isEmpty {
                Text(specialty.code)
                    .font(.caption.bold())
                    .foregroundStyle(.systemBlue01)
            }
            Text(institutionName)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let level = specialty.educationLevel, !level.isEmpty {
                Text(level)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !specialty.studyForms.isEmpty {
                Text(specialty.studyForms.formatted())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if specialty.requiresVerification == true {
                Label("Данные требуют проверки", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ApplicationsView: View {
    @State private var model: ApplicationsViewModel

    init(applicantID: String = "") {
        _model = State(initialValue: ApplicationsViewModel(applicantID: applicantID))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ApplicantPageHeader(title: "Мои заявления", subtitle: "Контролируй каждый этап поступления")
                Picker("Статус", selection: $model.filter) {
                    Text("Все · \(model.count(for: .all))").tag(ApplicationsViewModel.Filter.all)
                    Text("В работе · \(model.count(for: .active))").tag(ApplicationsViewModel.Filter.active)
                    Text("Принято · \(model.count(for: .accepted))").tag(ApplicationsViewModel.Filter.accepted)
                }
                .pickerStyle(.segmented)

                if model.isLoading && model.applications.isEmpty {
                    ProgressView("Загрузка заявлений…")
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else if model.visibleApplications.isEmpty {
                    EmptyCatalogView(
                        icon: "doc.text",
                        title: "Заявлений пока нет",
                        message: "Выберите специальность и отправьте первое заявление."
                    )
                    .frame(minHeight: 260)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(model.visibleApplications) { application in
                            NavigationLink {
                                ApplicationStatusView(application: application)
                            } label: {
                                ApplicationCard(application: application)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }

                NavigationLink {
                    NewApplicationView(applicantID: model.applicantID) {
                        Task { await model.load() }
                    }
                } label: {
                    ApplicantPrimaryButton(title: "Подать новое заявление")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(.systemWhite)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .refreshable { await model.load() }
        .toolbar {
            NavigationLink {
                PrioritiesView(applicantID: model.applicantID)
            } label: {
                Image(systemName: "list.number")
            }
        }
    }
}

struct OpportunitiesView: View {
    let applicantID: String

    init(applicantID: String = "") {
        self.applicantID = applicantID
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ApplicantPageHeader(title: "Возможности", subtitle: "Выбирай следующий шаг")
                OpportunitySearchCard()
                Text("Каталоги")
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                NavigationLink {
                    InstitutionsSearchView()
                } label: {
                    OpportunityCard(
                        title: "Учебные заведения",
                        subtitle: "Найдите университет или колледж по названию и городу",
                        icon: "building.columns"
                    )
                }
                NavigationLink {
                    SpecialtiesSearchView(applicantID: applicantID)
                } label: {
                    OpportunityCard(
                        title: "Специальности",
                        subtitle: "Выберите направление и подходящее учебное заведение",
                        icon: "book.closed"
                    )
                }
                Text("Персональные приглашения появятся здесь после подключения приёмных кампаний.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            .padding(20)
        }
        .background(.systemWhite)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    AssistantView()
                } label: {
                    Image(systemName: "sparkles")
                }
                .accessibilityLabel("AI-помощник")

                NavigationLink {
                    AnalyticsView()
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
                NavigationLink {
                    NotificationsView()
                } label: {
                    Image(systemName: "bell")
                }
            }
        }
    }
}

private struct OpportunitySearchCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
            Text("Поиск возможностей")
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(14)
        .background(.systemGrey1.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct OpportunityCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.systemBlue01)
                .frame(width: 46, height: 46)
                .background(.systemBlue01.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.systemGrey1.opacity(0.25))
        }
    }
}

struct ProfileView: View {
    let profile: ApplicantProfile?
    let profileStatus: ProfileStatus
    let onEditProfile: () -> Void
    let onEditDocuments: () -> Void
    let onSignOut: () -> Void
    let userID: String
    let onDeleteAccount: (String) async throws -> Void
    @State private var showsDeleteAccount = false
    @State private var deletePassword = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ApplicantPageHeader(title: "Мой профиль", subtitle: "Всё важное для поступления", showsBell: false)

                NavigationLink {
                    AvatarEditorView()
                } label: {
                    ApplicantProfileHero(profile: profile, profileStatus: profileStatus)
                }
                .buttonStyle(.plain)

            if let profile {
                HStack {
                    Text("Цифровой профиль")
                        .font(.title2.bold())
                        .foregroundStyle(.systemDarkBlue)
                    Spacer()
                    Text("\(profile.completionPercentage)%")
                        .font(.title2.bold())
                        .foregroundStyle(.systemBlue01)
                }
                ProgressView(value: Double(profile.completionPercentage), total: 100)
                    .tint(.systemBlue01)

                VStack(spacing: 12) {
                    NavigationLink {
                        DigitalProfileView(profile: profile, onEditProfile: onEditProfile)
                    } label: {
                        ApplicantMenuRow(icon: "person", title: "Личные данные", subtitle: "Контакты и паспорт")
                    }
                    NavigationLink {
                        DocumentsOverviewView(
                            documents: profile.documents,
                            onEditDocuments: onEditDocuments
                        )
                    } label: {
                        ApplicantMenuRow(icon: "doc.text", title: "Документы", subtitle: "Загруженные документы и проверка")
                    }
                    Button(action: onEditProfile) {
                        ApplicantMenuRow(icon: "star", title: "Достижения", subtitle: "Олимпиады, конкурсы и проекты")
                    }
                }
                .buttonStyle(.plain)
            } else {
                ContentUnavailableView {
                    Label("Профиль ещё не заполнен", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("Заполните данные сейчас или вернитесь к этому позже.")
                } actions: {
                    Button("Заполнить профиль", action: onEditProfile)
                        .buttonStyle(.borderedProminent)
                        .tint(.systemBlue01)
                }
            }

            if profileStatus == .inProgress {
                Section {
                    Button("Продолжить заполнение", action: onEditProfile)
                }
            }

            VStack(spacing: 12) {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    ApplicantMenuRow(icon: "bell", title: "Уведомления", subtitle: "Настройки оповещений")
                }
                NavigationLink {
                    SecurityAndAppearanceSettingsView()
                } label: {
                    ApplicantMenuRow(
                        icon: "circle.lefthalf.filled",
                        title: "Внешний вид и защита",
                        subtitle: "Тема приложения и Face ID"
                    )
                }
                Button("Выйти", role: .destructive, action: onSignOut)
                    .frame(maxWidth: .infinity, minHeight: 48)
                Button("Удалить аккаунт", role: .destructive) {
                    showsDeleteAccount = true
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(.systemWhite)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsDeleteAccount) {
            NavigationStack {
                Form {
                    Section {
                        Text("Аккаунт, профиль, заявления и локальный аватар будут удалены без возможности восстановления.")
                            .foregroundStyle(.secondary)
                        SecureField("Текущий пароль", text: $deletePassword)
                            .textContentType(.password)
                    } header: {
                        Text("Подтверждение удаления")
                    }

                    if let deleteError {
                        Text(deleteError).font(.caption).foregroundStyle(.red)
                    }

                    Section {
                        Button("Удалить аккаунт навсегда", role: .destructive) {
                            Task { await deleteAccount() }
                        }
                        .disabled(deletePassword.isEmpty || isDeletingAccount)
                    }
                }
                .navigationTitle("Удаление аккаунта")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showsDeleteAccount = false }
                    }
                }
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled(isDeletingAccount)
        }
    }

    private func fullName(_ profile: ApplicantProfile) -> String {
        [
            profile.personal.lastName,
            profile.personal.firstName,
            profile.personal.patronymic
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        deleteError = nil
        defer { isDeletingAccount = false }
        do {
            try await onDeleteAccount(deletePassword)
            showsDeleteAccount = false
        } catch {
            deleteError = UserFacingError.message(
                for: error,
                fallback: "Не удалось удалить аккаунт. Проверьте пароль и попробуйте снова."
            )
        }
    }
}

private struct ApplicantPageHeader: View {
    let title: String
    let subtitle: String
    var showsBell = true

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("VECTOR / АБИТУРИЕНТ")
                .font(.caption.bold())
                .foregroundStyle(.systemBlue01)
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.systemDarkBlue)
                Spacer()
                if showsBell {
                    Image(systemName: "bell")
                        .font(.title3)
                        .foregroundStyle(.systemBlue01)
                }
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }
}

private struct ApplicantPrimaryButton: View {
    let title: String

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "arrow.right")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ApplicantMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.systemBlue01)
                .frame(width: 44, height: 44)
                .background(Color.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.systemDarkBlue)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.systemWhite)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ApplicantProfileHero: View {
    let profile: ApplicantProfile?
    let profileStatus: ProfileStatus

    private var initials: String {
        guard let profile else { return "—" }
        return String(profile.personal.firstName.prefix(1) + profile.personal.lastName.prefix(1))
    }

    private var name: String {
        guard let profile else { return "Профиль не заполнен" }
        return [profile.personal.firstName, profile.personal.lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var body: some View {
        HStack(spacing: 18) {
            Text(initials.uppercased())
                .font(.title.bold())
                .foregroundStyle(.systemBlue01)
                .frame(width: 72, height: 72)
                .background(Color.systemBlue01.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
            VStack(alignment: .leading, spacing: 7) {
                Text(name).font(.title3.bold()).foregroundStyle(.systemDarkBlue)
                Text("Абитуриент").foregroundStyle(.secondary)
                Text(profileStatus == .complete ? "Профиль подтверждён" : "Профиль требует заполнения")
                    .font(.caption.bold())
                    .foregroundStyle(profileStatus == .complete ? .green : .orange)
            }
            Spacer()
        }
        .padding(20)
        .background(Color.systemGrey1.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct EmptyCatalogView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
    }
}

#Preview {
    MainTabView(profile: ApplicantProfile())
}
