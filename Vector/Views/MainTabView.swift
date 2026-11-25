import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private(set) var institutions: [InstitutionRecord] = []
    private(set) var specialties: [FavoriteSpecialty] = []

    private let institutionsKey = "vector.favorites.institutions.v1"
    private let specialtiesKey = "vector.favorites.specialties.v1"

    private init() {
        institutions = Self.load([InstitutionRecord].self, key: institutionsKey)
        specialties = Self.load([FavoriteSpecialty].self, key: specialtiesKey)
    }

    func contains(institutionID: String) -> Bool {
        institutions.contains { $0.id == institutionID }
    }

    func contains(institutionID: String, specialtyID: String) -> Bool {
        specialties.contains { $0.id == "\(institutionID):\(specialtyID)" }
    }

    func toggle(_ institution: InstitutionRecord) {
        if let index = institutions.firstIndex(where: { $0.id == institution.id }) {
            institutions.remove(at: index)
        } else {
            institutions.append(institution)
        }
        save(institutions, key: institutionsKey)
    }

    func toggle(specialty: SpecialtyRecord, institution: InstitutionRecord) {
        let favorite = FavoriteSpecialty(specialty: specialty, institution: institution)
        if let index = specialties.firstIndex(where: { $0.id == favorite.id }) {
            specialties.remove(at: index)
        } else {
            specialties.append(favorite)
        }
        save(specialties, key: specialtiesKey)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T where T: RangeReplaceableCollection {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(type, from: data) else {
            return T()
        }
        return value
    }
}

struct FavoriteSpecialty: Codable, Identifiable {
    let specialty: SpecialtyRecord
    let institution: InstitutionRecord

    var id: String { "\(institution.id):\(specialty.id)" }
}

struct MainTabView: View {
    private enum TabDestination: Hashable {
        case home
        case applications
        case opportunities
        case assistant
        case profile
    }

    let userID: String
    let profile: ApplicantProfile?
    let profileStatus: ProfileStatus
    let onEditProfile: () -> Void
    let onEditDocuments: () -> Void
    let onSignOut: () -> Void
    let onDeleteAccount: (String) async throws -> Void

    @State private var selectedTab = TabDestination.home

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
        TabView(selection: $selectedTab) {
            Tab("Главная", systemImage: "house", value: .home) {
                NavigationStack {
                    HomeView(
                        applicantID: userID,
                        profile: profile,
                        profileStatus: profileStatus,
                        onEditProfile: onEditProfile
                    )
                }
            }

            Tab("Заявления", systemImage: "doc.text", value: .applications) {
                NavigationStack {
                    ApplicationsView(applicantID: userID)
                }
            }

            Tab("Возможности", systemImage: "star", value: .opportunities) {
                NavigationStack {
                    OpportunitiesView(applicantID: userID, profile: profile)
                }
            }

            Tab("ИИ", systemImage: "sparkles", value: .assistant) {
                NavigationStack {
                    AssistantView {
                        selectedTab = .home
                    }
                }
            }

            Tab("Профиль", systemImage: "person", value: .profile) {
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
    let applicantID: String
    let profile: ApplicantProfile?
    let profileStatus: ProfileStatus
    let onEditProfile: () -> Void

    @State private var applications: ApplicationsViewModel

    init(
        applicantID: String,
        profile: ApplicantProfile?,
        profileStatus: ProfileStatus,
        onEditProfile: @escaping () -> Void
    ) {
        self.applicantID = applicantID
        self.profile = profile
        self.profileStatus = profileStatus
        self.onEditProfile = onEditProfile
        _applications = State(initialValue: ApplicationsViewModel(applicantID: applicantID))
    }

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
                NavigationLink {
                    AdmissionPlanView(
                        profile: profile,
                        profileStatus: profileStatus,
                        applications: applications.applications,
                        applicantID: applicantID
                    )
                } label: {
                    HomeApplicationsCard(
                        applications: applications.applications,
                        isLoading: applications.isLoading
                    )
                }
                .buttonStyle(.plain)
                Text("Найти")
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                HomeNavigationSection()

                NavigationLink {
                    FavoritesView(applicantID: applicantID)
                } label: {
                    HomeFeatureCard(
                        title: "Избранное",
                        subtitle: "Сохранённые учреждения и специальности",
                        icon: "heart.fill"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color.systemBlue01.opacity(0.035))
        .task { await loadHome() }
        .refreshable { await loadHome() }
//        .navigationTitle("Vector")
    }

    private func loadHome() async {
        await applications.load()
        await NotificationService.shared.scheduleDeadlineReminders(
            for: applications.applications
        )
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
    let applications: [ApplicationRecord]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Мои заявления", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(.systemDarkBlue)
            if isLoading && applications.isEmpty {
                ProgressView("Обновляем план…")
            } else if applications.isEmpty {
                Text("Начните с выбора учреждения и создайте первое заявление.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(applications.count) заявлений · \(activeCount) требуют внимания")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
                    .tint(.systemBlue01)
                Label("Открыть план поступления", systemImage: "calendar.badge.checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.systemBlue01)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private var activeCount: Int {
        applications.filter { ![.accepted, .rejected].contains($0.status) }.count
    }

    private var progress: Double {
        guard !applications.isEmpty else { return 0 }
        let completed = applications.filter { [.accepted, .rejected].contains($0.status) }.count
        return Double(completed) / Double(applications.count)
    }
}

struct AdmissionPlanView: View {
    let profile: ApplicantProfile?
    let profileStatus: ProfileStatus
    let applications: [ApplicationRecord]
    let applicantID: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AdmissionPlanProgress(tasks: tasks)
                AdmissionNextAction(tasks: tasks)
                AdmissionTaskSection(tasks: tasks)
                AdmissionDeadlineSection(applications: applications)

                NavigationLink {
                    NewApplicationView(applicantID: applicantID)
                } label: {
                    Label("Добавить заявление", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(Color.systemBlue01.opacity(0.035))
        .navigationTitle("Мой план")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tasks: [AdmissionPlanTask] {
        let selectedDocuments = profile?.documents.filter { $0.status == .selected || $0.status == .uploaded }.count ?? 0
        return [
            AdmissionPlanTask(
                id: "profile",
                title: "Заполнить цифровой профиль",
                detail: profileStatus == .complete ? "Профиль готов" : "Добавьте обязательные личные данные",
                icon: "person.crop.circle",
                isComplete: profileStatus == .complete
            ),
            AdmissionPlanTask(
                id: "preferences",
                title: "Указать предпочтения",
                detail: "Направление, город, форма обучения и финансирование",
                icon: "slider.horizontal.3",
                isComplete: profile?.additional.hasEducationPreferences == true
            ),
            AdmissionPlanTask(
                id: "documents",
                title: "Подготовить документы",
                detail: selectedDocuments == 0 ? "Документы ещё не выбраны" : "Добавлено документов: \(selectedDocuments)",
                icon: "doc.badge.plus",
                isComplete: selectedDocuments > 0
            ),
            AdmissionPlanTask(
                id: "application",
                title: "Подать первое заявление",
                detail: applications.isEmpty ? "Выберите учреждение и специальность" : "Заявлений: \(applications.count)",
                icon: "paperplane",
                isComplete: !applications.isEmpty
            ),
            AdmissionPlanTask(
                id: "priorities",
                title: "Проверить приоритеты",
                detail: applications.count > 1 ? "Расположите варианты в желаемом порядке" : "Появится после второго заявления",
                icon: "list.number",
                isComplete: applications.count > 1 && prioritiesAreSequential
            ),
        ]
    }

    private var prioritiesAreSequential: Bool {
        applications.map(\.priority).sorted() == Array(1...applications.count)
    }
}

struct AdmissionPlanTask: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let isComplete: Bool
}

private struct AdmissionPlanProgress: View {
    let tasks: [AdmissionPlanTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Готовность к поступлению")
                .font(.headline)
            Text("\(percentage)%")
                .font(.largeTitle.bold())
            ProgressView(value: Double(completed), total: Double(max(tasks.count, 1)))
                .tint(.white)
            Text("Выполнено \(completed) из \(tasks.count) шагов")
                .font(.caption)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 20))
    }

    private var completed: Int { tasks.filter(\.isComplete).count }
    private var percentage: Int { tasks.isEmpty ? 0 : completed * 100 / tasks.count }
}

private struct AdmissionNextAction: View {
    let tasks: [AdmissionPlanTask]

    var body: some View {
        if let task = tasks.first(where: { !$0.isComplete }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Что делать сейчас")
                    .font(.caption.bold())
                    .foregroundStyle(.systemBlue01)
                Label(task.title, systemImage: task.icon)
                    .font(.headline)
                Text(task.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct AdmissionTaskSection: View {
    let tasks: [AdmissionPlanTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Шаги")
                .font(.title2.bold())
            ForEach(tasks) { task in
                HStack(spacing: 14) {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : task.icon)
                        .font(.title3)
                        .foregroundStyle(task.isComplete ? .green : .systemBlue01)
                        .frame(width: 42, height: 42)
                        .background(Color.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title).font(.headline)
                        Text(task.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(.systemWhite, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

private struct AdmissionDeadlineSection: View {
    let applications: [ApplicationRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Дедлайны")
                .font(.title2.bold())
            if deadlines.isEmpty {
                Text("Учреждения пока не назначили сроки. Когда срок появится, он будет показан здесь и в уведомлениях.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.systemWhite, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(deadlines) { application in
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(application.institutionName).font(.headline)
                            Text(application.submissionDeadline ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.systemWhite, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var deadlines: [ApplicationRecord] {
        applications.filter { !($0.submissionDeadline ?? "").isEmpty }
    }
}

struct FavoritesView: View {
    let applicantID: String
    @State private var favorites = FavoritesStore.shared

    var body: some View {
        List {
            if favorites.institutions.isEmpty && favorites.specialties.isEmpty {
                ContentUnavailableView {
                    Label("Избранное пусто", systemImage: "heart")
                } description: {
                    Text("Сохраняйте учреждения и специальности из их карточек.")
                }
            }

            if !favorites.institutions.isEmpty {
                Section("Учреждения") {
                    ForEach(favorites.institutions) { institution in
                        NavigationLink {
                            InstitutionDetailsView(institution: institution)
                        } label: {
                            InstitutionRow(institution: institution)
                        }
                    }
                    .onDelete { offsets in
                        for institution in offsets.map({ favorites.institutions[$0] }) {
                            favorites.toggle(institution)
                        }
                    }
                }
            }

            if !favorites.specialties.isEmpty {
                Section("Специальности") {
                    ForEach(favorites.specialties) { favorite in
                        NavigationLink {
                            SpecialtyDetailsView(
                                specialty: favorite.specialty,
                                institution: favorite.institution,
                                applicantID: applicantID
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(favorite.specialty.name).font(.headline)
                                Text(favorite.institution.name).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for favorite in offsets.map({ favorites.specialties[$0] }) {
                            favorites.toggle(specialty: favorite.specialty, institution: favorite.institution)
                        }
                    }
                }
            }
        }
        .navigationTitle("Избранное")
        .navigationBarTitleDisplayMode(.inline)
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
            InstitutionVisual(imageURL: institution.imageURL, type: institution.type)
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
    @State private var favorites = FavoritesStore.shared

    var body: some View {
        List {
            InstitutionVisual(imageURL: institution.imageURL, type: institution.type, isHero: true)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

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
                Button {
                    favorites.toggle(institution)
                } label: {
                    Label(
                        favorites.contains(institutionID: institution.id)
                            ? "Убрать из избранного"
                            : "Добавить в избранное",
                        systemImage: favorites.contains(institutionID: institution.id)
                            ? "heart.fill"
                            : "heart"
                    )
                }

                NavigationLink {
                    InstitutionSpecialtiesView(
                        institution: institution
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
    let institution: InstitutionRecord
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
                    NavigationLink {
                        SpecialtyDetailsView(
                            specialty: specialty,
                            institution: institution,
                            applicantID: ""
                        )
                    } label: {
                        SpecialtyRow(specialty: specialty, institutionName: institution.name)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Специальности")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(institutionID: institution.id) }
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
                            institution: selectedInstitution(for: specialty),
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
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SpecialtyComparisonView()
                } label: {
                    Image(systemName: "square.stack.3d.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
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
        }
        .task { await model.load() }
    }

    private func selectedInstitution(for specialty: SpecialtyRecord) -> InstitutionRecord? {
        let institutions = model.institutions(for: specialty.id)
        guard let selectedInstitutionID = model.selectedInstitutionID else {
            return institutions.first
        }
        return institutions.first { $0.id == selectedInstitutionID } ?? institutions.first
    }
}

private struct SpecialtyRow: View {
    let specialty: SpecialtyRecord
    let institutionName: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SpecialtyVisual(specialty: specialty)
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

                if !model.applications.isEmpty {
                    ApplicationPrioritiesLink(
                        applicantID: model.applicantID,
                        applicationCount: model.applications.count
                    )
                }

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
    }
}

private struct ApplicationPrioritiesLink: View {
    let applicantID: String
    let applicationCount: Int

    var body: some View {
        NavigationLink {
            PrioritiesView(applicantID: applicantID)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.number")
                    .font(.title3)
                    .foregroundStyle(.systemBlue01)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Приоритеты заявлений")
                        .font(.headline)
                        .foregroundStyle(.systemDarkBlue)
                    Text("Заявлений: \(applicationCount). Расставьте их в нужном порядке.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.systemGrey1.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct CachedAIRecommendation: Codable {
    let prompt: String
    let answer: String
    let createdAt: Date
}

struct OpportunitiesView: View {
    let applicantID: String
    let profile: ApplicantProfile?

    @State private var recommendation: String?
    @State private var isLoadingRecommendation = false
    @State private var recommendationError: String?

    init(applicantID: String = "", profile: ApplicantProfile? = nil) {
        self.applicantID = applicantID
        self.profile = profile
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ApplicantPageHeader(title: "Возможности", subtitle: "Персональный подбор для поступления")

                Text("Рекомендовано AI")
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)

                AIRecommendationCard(
                    recommendation: recommendation,
                    isLoading: isLoadingRecommendation,
                    errorMessage: recommendationError,
                    canPersonalize: profile != nil,
                    onRetry: {
                        Task { await loadRecommendation(force: true) }
                    }
                )

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
                .buttonStyle(.plain)

                NavigationLink {
                    SpecialtiesSearchView(applicantID: applicantID)
                } label: {
                    OpportunityCard(
                        title: "Специальности",
                        subtitle: "Выберите направление и подходящее учебное заведение",
                        icon: "book.closed"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(.systemWhite)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadRecommendation()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    SpecialtyComparisonView()
                } label: {
                    Image(systemName: "square.stack.3d.up")
                }

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

    private func loadRecommendation(force: Bool = false) async {
        guard profile != nil else { return }
        guard force || recommendation == nil else { return }
        guard !isLoadingRecommendation else { return }

        if !force, let cached = cachedRecommendation,
           cached.prompt == recommendationPrompt,
           cached.createdAt > Date.now.addingTimeInterval(-6 * 60 * 60) {
            recommendation = cached.answer
            return
        }

        isLoadingRecommendation = true
        recommendationError = nil
        defer { isLoadingRecommendation = false }

        do {
            let response = try await AssistantService.chat(message: recommendationPrompt)
            recommendation = response.answer
            saveCachedRecommendation(response.answer)
        } catch {
            recommendationError = UserFacingError.message(
                for: error,
                fallback: "Не удалось обновить рекомендации. Попробуйте ещё раз."
            )
        }
    }

    private var recommendationCacheKey: String {
        "vector.ai-recommendation.v2.\(applicantID.isEmpty ? "anonymous" : applicantID)"
    }

    private var cachedRecommendation: CachedAIRecommendation? {
        guard let data = UserDefaults.standard.data(forKey: recommendationCacheKey) else { return nil }
        return try? JSONDecoder().decode(CachedAIRecommendation.self, from: data)
    }

    private func saveCachedRecommendation(_ answer: String) {
        let value = CachedAIRecommendation(prompt: recommendationPrompt, answer: answer, createdAt: .now)
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: recommendationCacheKey)
    }

    private var recommendationPrompt: String {
        guard let profile else { return "" }

        var details: [String] = []
        if let status = profile.education.status {
            details.append("статус: \(status.title)")
        }
        if !profile.institution.locality.isEmpty {
            details.append("город: \(profile.institution.locality)")
        }
        if !profile.institution.profileClass.isEmpty {
            details.append("профиль обучения: \(profile.institution.profileClass)")
        }

        let preferences = profile.additional
        if !preferences.preferredDirections.isEmpty {
            details.append("интересующие направления: \(preferences.preferredDirections)")
        }
        if !preferences.preferredCities.isEmpty {
            details.append("предпочтительные города: \(preferences.preferredCities)")
        }
        if !preferences.preferredEducationLevel.isEmpty {
            details.append("желаемый уровень: \(preferences.preferredEducationLevel)")
        }
        if !preferences.preferredStudyForm.isEmpty {
            details.append("форма обучения: \(preferences.preferredStudyForm)")
        }
        if !preferences.fundingPreference.isEmpty {
            details.append("финансирование: \(preferences.fundingPreference)")
        }
        if preferences.willingToRelocate {
            details.append("готовность к переезду: да")
        }

        let exams = profile.examResults
            .filter { !$0.subject.isEmpty || !$0.score.isEmpty }
            .map { "\($0.subject): \($0.score)" }
            .joined(separator: ", ")
        if !exams.isEmpty {
            details.append("результаты экзаменов: \(exams)")
        }

        let context = details.isEmpty ? "профиль пока заполнен частично" : details.joined(separator: "; ")
        return """
        Подбери для абитуриента 3 подходящих направления или учреждения из справочника VECTOR.
        Дай короткий список: название и одно предложение, почему подходит.
        Данные профиля: \(context).
        Не придумывай проходные баллы и обязательно предупреди, что актуальность нужно проверить на официальном сайте.
        """
    }
}

private struct AIRecommendationCard: View {
    let recommendation: String?
    let isLoading: Bool
    let errorMessage: String?
    let canPersonalize: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Подбор по вашему профилю", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.systemBlue01)

            if !canPersonalize {
                Text("Заполните профиль, чтобы помощник подобрал подходящие направления и учреждения.")
                    .foregroundStyle(.secondary)
            } else if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Подбираю варианты…")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Попробовать ещё раз", action: onRetry)
                    .font(.subheadline.bold())
            } else if let recommendation {
                Text(markdown: recommendation)
                    .font(.subheadline)
                    .foregroundStyle(.systemDarkBlue)
                    .textSelection(.enabled)

                NavigationLink {
                    AssistantView()
                } label: {
                    Label("Обсудить с помощником", systemImage: "message")
                        .font(.subheadline.bold())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.systemBlue01.opacity(0.18))
        }
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

private extension Text {
    init(markdown source: String) {
        if let value = try? AttributedString(markdown: source) {
            self.init(value)
        } else {
            self.init(source)
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
    @State private var avatarImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ApplicantPageHeader(title: "Мой профиль", subtitle: "Всё важное для поступления", showsBell: false)

                NavigationLink {
                    AvatarEditorView(userID: userID)
                } label: {
                    ApplicantProfileHero(
                        profile: profile,
                        profileStatus: profileStatus,
                        avatarImage: avatarImage
                    )
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
                    NotificationsView()
                } label: {
                    ApplicantMenuRow(icon: "bell", title: "Уведомления", subtitle: "Статусы заявлений и сообщения")
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
                NavigationLink {
                    AccountConnectionsView()
                } label: {
                    ApplicantMenuRow(icon: "person.badge.key", title: "Вход и email", subtitle: "Привязка Google и подтверждение почты")
                }
                Button("Выйти", role: .destructive, action: onSignOut)
                    .frame(maxWidth: .infinity, minHeight: 48)
                Button("Удалить аккаунт", role: .destructive) {
                    showsDeleteAccount = true
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 120)
        }
        .background(.systemWhite)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: userID) { loadAvatar() }
        .onReceive(NotificationCenter.default.publisher(for: .avatarDidChange)) { notification in
            guard notification.object as? String == userID else { return }
            loadAvatar()
        }
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

    @MainActor
    private func loadAvatar() {
        guard let data = try? LocalAvatarStorage.shared.load(userID: userID) else {
            avatarImage = nil
            return
        }
        avatarImage = UIImage(data: data)
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
    let avatarImage: UIImage?

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
            Group {
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(initials.uppercased())
                        .font(.title.bold())
                        .foregroundStyle(.systemBlue01)
                }
            }
            .frame(width: 72, height: 72)
            .background(Color.systemBlue01.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 22))
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
