import Observation
import SwiftUI

struct ComparisonSelection: Codable, Equatable, Identifiable {
    let institutionID: String
    let specialtyID: String

    var id: String { institutionID + ":" + specialtyID }
}

@MainActor
@Observable
final class ComparisonStore {
    static let shared = ComparisonStore()
    private(set) var selections: [ComparisonSelection] = []
    let maximumCount = 4

    private let defaultsKey = "vector.specialty-comparison"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ComparisonSelection].self, from: data) else {
            return
        }
        selections = Array(uniqueSelections(decoded).prefix(maximumCount))
    }

    func contains(institutionID: String, specialtyID: String) -> Bool {
        selections.contains { $0.institutionID == institutionID && $0.specialtyID == specialtyID }
    }

    @discardableResult
    func toggle(institutionID: String, specialtyID: String) -> Bool {
        let selection = ComparisonSelection(institutionID: institutionID, specialtyID: specialtyID)
        if let index = selections.firstIndex(of: selection) {
            selections.remove(at: index)
            persist()
            return true
        }
        guard selections.count < maximumCount else { return false }
        selections.append(selection)
        persist()
        return true
    }

    func remove(_ selection: ComparisonSelection) {
        selections.removeAll { $0 == selection }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(selections) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private func uniqueSelections(_ values: [ComparisonSelection]) -> [ComparisonSelection] {
        var identifiers = Set<String>()
        return values.filter { identifiers.insert($0.id).inserted }
    }
}

nonisolated private struct ComparisonSpecialtyDTO: Decodable, Sendable {
    let id, institutionId, name, code, educationLevel, qualification: String
    let studyForms: [String]
    let faculty, description: String
    let duration, budgetPlaces, paidPlaces: Int?
}

nonisolated private struct ComparisonScoreDTO: Decodable, Sendable {
    let specialtyId: String
    let admissionYear: Int
    let studyForm, fundingType: String
    let score: Double
}

private struct ComparisonOption: Identifiable {
    let selection: ComparisonSelection
    let institutionName: String
    let specialtyName: String
    let code: String
    let educationLevel: String
    let qualification: String
    let studyForms: [String]
    let faculty: String
    let duration: Int?
    let budgetPlaces: Int?
    let paidPlaces: Int?
    let latestScore: ComparisonScoreDTO?

    var id: String { selection.id }
}

@MainActor
@Observable
private final class ComparisonViewModel {
    var options: [ComparisonOption] = []
    var isLoading = false
    var errorMessage: String?

    func load(selections: [ComparisonSelection]) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let institutions = try await BackendCatalogInstitutionRepository().fetchPublishedInstitutions()
            var loaded: [ComparisonOption] = []
            for selection in selections {
                let specialties: [ComparisonSpecialtyDTO] = try await BackendAPIClient.shared.request(
                    "/api/v1/catalog/institutions/\(selection.institutionID)/specialties"
                )
                guard let specialty = specialties.first(where: { $0.id == selection.specialtyID }) else { continue }
                let scores: [ComparisonScoreDTO] = try await BackendAPIClient.shared.request(
                    "/api/v1/catalog/institutions/\(selection.institutionID)/passing-scores"
                )
                let score = scores.filter { $0.specialtyId == selection.specialtyID }.sorted { lhs, rhs in
                        if lhs.admissionYear == rhs.admissionYear { return lhs.score > rhs.score }
                        return lhs.admissionYear > rhs.admissionYear
                    }
                    .first
                loaded.append(ComparisonOption(
                    selection: selection,
                    institutionName: institutions.first(where: { $0.id == selection.institutionID })?.name ?? "Учреждение",
                    specialtyName: specialty.name,
                    code: specialty.code,
                    educationLevel: specialty.educationLevel,
                    qualification: specialty.qualification,
                    studyForms: specialty.studyForms,
                    faculty: specialty.faculty,
                    duration: specialty.duration,
                    budgetPlaces: specialty.budgetPlaces,
                    paidPlaces: specialty.paidPlaces,
                    latestScore: score
                ))
            }
            options = loaded
        } catch {
            errorMessage = UserFacingError.message(for: error, fallback: "Не удалось загрузить сравнение.")
        }
    }
}

struct SpecialtyComparisonView: View {
    @State private var store = ComparisonStore.shared
    @State private var model = ComparisonViewModel()

    var body: some View {
        Group {
            if model.isLoading && model.options.isEmpty {
                ProgressView("Загружаем сравнение…")
            } else if let errorMessage = model.errorMessage, model.options.isEmpty {
                ContentUnavailableView("Не удалось загрузить сравнение", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if store.selections.isEmpty {
                ContentUnavailableView(
                    "Нет вариантов для сравнения",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("Откройте специальность и добавьте её в сравнение.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(model.options) { option in
                            ComparisonOptionCard(option: option) {
                                store.remove(option.selection)
                                Task { await model.load(selections: store.selections) }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(.systemWhite)
        .navigationTitle("Сравнение")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: store.selections) { await model.load(selections: store.selections) }
    }
}

private struct ComparisonOptionCard: View {
    let option: ComparisonOption
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(option.specialtyName).font(.headline).foregroundStyle(.systemDarkBlue)
                    Text(option.institutionName).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel("Удалить из сравнения")
            }
            Divider()
            ComparisonValueRow(title: "Код", value: option.code)
            ComparisonValueRow(title: "Уровень", value: option.educationLevel)
            ComparisonValueRow(title: "Формы", value: option.studyForms.formatted())
            ComparisonValueRow(title: "Факультет", value: option.faculty)
            ComparisonValueRow(title: "Срок обучения", value: option.duration.map { "\($0) года" } ?? "")
            ComparisonValueRow(title: "Бюджетных мест", value: option.budgetPlaces.map(String.init) ?? "")
            ComparisonValueRow(title: "Платных мест", value: option.paidPlaces.map(String.init) ?? "")
            ComparisonValueRow(
                title: "Последний проходной балл",
                value: option.latestScore.map {
                    "\($0.score.formatted(.number.precision(.fractionLength(0...2)))) · \($0.admissionYear) · \($0.fundingType)"
                } ?? ""
            )
        }
        .padding(18)
        .background(Color.systemGrey1.opacity(0.3), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ComparisonValueRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title, value: value.isEmpty ? "Нет данных" : value)
            .font(.subheadline)
    }
}

nonisolated private struct CatalogBreakdownDTO: Decodable, Sendable, Identifiable {
    let label: String
    let count: Int
    var id: String { label }
}

nonisolated private struct PassingScoreYearDTO: Decodable, Sendable, Identifiable {
    let year, count: Int
    var id: Int { year }
}

nonisolated private struct CatalogAnalyticsDTO: Decodable, Sendable {
    let institutions, specialties, programs, passingScores: Int
    let verifiedInstitutions, institutionsWithImages: Int
    let institutionTypes, leadingCities: [CatalogBreakdownDTO]
    let passingScoreYears: [PassingScoreYearDTO]
}

@MainActor
@Observable
private final class CatalogAnalyticsModel {
    var analytics: CatalogAnalyticsDTO?
    var isLoading = false
    var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            analytics = try await BackendAPIClient.shared.request("/api/v1/catalog/analytics")
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error, fallback: "Не удалось загрузить аналитику.")
        }
    }
}

struct AnalyticsView: View {
    @State private var model = CatalogAnalyticsModel()

    var body: some View {
        Group {
            if model.isLoading && model.analytics == nil {
                ProgressView("Загружаем аналитику…")
            } else if let analytics = model.analytics {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        AnalyticsSummarySection(analytics: analytics)
                        AnalyticsBreakdownSection(title: "Учреждения по типам", items: analytics.institutionTypes)
                        AnalyticsBreakdownSection(title: "Города с наибольшим выбором", items: analytics.leadingCities)
                        PassingScoreCoverageSection(items: analytics.passingScoreYears)
                        Text("Показатели отражают опубликованные и доступные в Vector данные, а не официальную статистику всей приёмной кампании.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                }
                .refreshable { await model.load() }
            } else {
                ContentUnavailableView(
                    "Аналитика недоступна",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(model.errorMessage ?? "Попробуйте обновить экран.")
                )
            }
        }
        .background(.systemWhite)
        .navigationTitle("Аналитика каталога")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

private struct AnalyticsSummarySection: View {
    let analytics: CatalogAnalyticsDTO
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            AnalyticsMetricCard(value: analytics.institutions, title: "Учреждений", icon: "building.columns")
            AnalyticsMetricCard(value: analytics.specialties, title: "Специальностей", icon: "book.closed")
            AnalyticsMetricCard(value: analytics.programs, title: "Программ", icon: "list.bullet.rectangle")
            AnalyticsMetricCard(value: analytics.passingScores, title: "Проходных баллов", icon: "number.circle")
            AnalyticsMetricCard(value: analytics.verifiedInstitutions, title: "Проверенных записей", icon: "checkmark.seal")
            AnalyticsMetricCard(value: analytics.institutionsWithImages, title: "Карточек с фото", icon: "photo")
        }
    }
}

private struct AnalyticsMetricCard: View {
    let value: Int
    let title: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(.systemBlue01)
            Text(value, format: .number).font(.title.bold()).foregroundStyle(.systemDarkBlue)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(Color.systemGrey1.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AnalyticsBreakdownSection: View {
    let title: String
    let items: [CatalogBreakdownDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(.systemDarkBlue)
            ForEach(items) { item in
                HStack {
                    Text(displayLabel(item.label))
                    Spacer()
                    Text(item.count, format: .number).fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
    }

    private func displayLabel(_ value: String) -> String {
        [
            "university": "Университеты",
            "college": "Колледжи",
            "higher_education_entry": "Высшее образование",
            "college_or_sso_provider": "ССО и колледжи"
        ][value] ?? value
    }
}

private struct PassingScoreCoverageSection: View {
    let items: [PassingScoreYearDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Проходные баллы по годам").font(.headline).foregroundStyle(.systemDarkBlue)
            if items.isEmpty {
                Text("Подтверждённые данные пока не опубликованы.").foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack {
                        Text(item.year, format: .number.grouping(.never))
                        Spacer()
                        Text("\(item.count) записей").fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}
