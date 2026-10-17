import SwiftUI

struct MainTabView: View {
    let profile: ApplicantProfile?
    let profileStatus: ProfileStatus
    let onEditProfile: () -> Void
    let onEditDocuments: () -> Void
    let onSignOut: () -> Void

    init(
        profile: ApplicantProfile? = nil,
        profileStatus: ProfileStatus = .notStarted,
        onEditProfile: @escaping () -> Void = {},
        onEditDocuments: @escaping () -> Void = {},
        onSignOut: @escaping () -> Void = {}
    ) {
        self.profile = profile
        self.profileStatus = profileStatus
        self.onEditProfile = onEditProfile
        self.onEditDocuments = onEditDocuments
        self.onSignOut = onSignOut
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

            Tab("Поиск", systemImage: "magnifyingglass") {
                NavigationStack {
                    CatalogView()
                }
            }

            Tab("Заявления", systemImage: "doc.text") {
                NavigationStack {
                    ApplicationsView()
                }
            }

            Tab("Возможности", systemImage: "sparkles") {
                NavigationStack {
                    OpportunitiesView()
                }
            }

            Tab("Профиль", systemImage: "person") {
                NavigationStack {
                    ProfileView(
                        profile: profile,
                        profileStatus: profileStatus,
                        onEditProfile: onEditProfile,
                        onEditDocuments: onEditDocuments,
                        onSignOut: onSignOut
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
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(name.isEmpty ? "Добро пожаловать!" : "Привет, \(name)! 👋")
                    .font(.title2.bold())
                    .foregroundStyle(.systemDarkBlue)
                Text("Твой путь к будущему начинается здесь")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(.systemBlue01.opacity(0.75))
        }
        .padding(.top, 8)
    }
}

struct ProfileCompletionCard: View {
    let percentage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Цифровой профиль")
                        .font(.headline)
                    Text("Заполнен на \(percentage)%")
                        .font(.caption)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }

            ProgressView(value: Double(percentage), total: 100)
                .tint(.white)

            HStack {
                HomeQuickAction(title: "Документы", icon: "doc.text")
                HomeQuickAction(title: "Достижения", icon: "trophy")
                HomeQuickAction(title: "Настройки", icon: "gearshape")
            }
        }
        .padding(18)
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
                    Picker("Тип", selection: $model.selectedType) {
                        Text("Все типы").tag(String?.none)
                        ForEach(model.types, id: \.self) { type in
                            Text(institutionTypeTitle(type)).tag(Optional(type))
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
                Text("\(institution.locality) • \(institution.type == "college" ? "Колледж" : "Университет")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            if institution.websiteURL != nil || institution.admissionsURL != nil {
                Section("Официальные ссылки") {
                    if let website = validURL(institution.websiteURL) {
                        Link("Сайт учреждения", destination: website)
                    }
                    if let admissions = validURL(institution.admissionsURL) {
                        Link("Приёмная комиссия", destination: admissions)
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
                Section {
                    LabeledContent("Данные проверены", value: date.formatted(date: .numeric, time: .omitted))
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
                    SpecialtyRow(
                        specialty: specialty,
                        institutionName: model.institutionName(for: specialty.institutionID)
                    )
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
            if !specialty.studyForms.isEmpty {
                Text(specialty.studyForms.formatted())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ApplicationsView: View {
    var body: some View {
        VStack {
            EmptyCatalogView(
                icon: "doc.text",
                title: "Заявлений пока нет",
                message: "Здесь появятся ваши заявления после отправки в учебное заведение."
            )

            NavigationLink("Создать заявление") {
                NewApplicationView()
            }
            .buttonStyle(.borderedProminent)
            .tint(.systemBlue01)
            .padding(.bottom, 24)
        }
        .navigationTitle("Мои заявления")
        .toolbar {
            NavigationLink {
                PrioritiesView()
            } label: {
                Image(systemName: "list.number")
            }
        }
    }
}

struct OpportunitiesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
                    SpecialtiesSearchView()
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
        .background(Color.systemBlue01.opacity(0.035))
        .navigationTitle("Возможности")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
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

    var body: some View {
        List {
            if let profile {
                Section {
                    NavigationLink {
                        DigitalProfileView(profile: profile, onEditProfile: onEditProfile)
                    } label: {
                        Label("Цифровой профиль", systemImage: "chart.pie")
                    }
                    NavigationLink {
                        DocumentsOverviewView(
                            documents: profile.documents,
                            onEditDocuments: onEditDocuments
                        )
                    } label: {
                        Label("Документы", systemImage: "doc.text")
                    }
                }

                Section("Основное") {
                    LabeledContent("ФИО", value: fullName(profile))
                    LabeledContent("Email", value: profile.contact.email)
                    LabeledContent("Телефон", value: profile.contact.phone)
                }

                Section("Образование") {
                    LabeledContent(
                        "Статус",
                        value: profile.education.status?.title ?? "Не указан"
                    )
                    LabeledContent(
                        "Учебное заведение",
                        value: profile.institution.name.isEmpty ? "Не указано" : profile.institution.name
                    )
                }

                Section("Адрес") {
                    LabeledContent(
                        "Страна",
                        value: GeographyCatalog.countryName(id: profile.address.countryID)
                    )
                    if !profile.address.regionID.isEmpty {
                        LabeledContent(
                            "Регион",
                            value: GeographyCatalog.regionName(
                                id: profile.address.regionID,
                                countryID: profile.address.countryID
                            )
                        )
                    }
                }

                Section {
                    Button("Редактировать профиль", action: onEditProfile)
                }
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

            Section {
                Button("Выйти", role: .destructive, action: onSignOut)
            }
        }
        .navigationTitle("Профиль")
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
