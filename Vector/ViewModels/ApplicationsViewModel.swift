import Foundation
import Observation

@MainActor
@Observable
final class ApplicationsViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case active
        case accepted

        var id: String { rawValue }
    }

    var applications: [ApplicationRecord] = []
    var filter: Filter = .all
    var isLoading = false
    var errorMessage: String?

    let applicantID: String
    private let repository: any ApplicationRepository

    init(applicantID: String, repository: (any ApplicationRepository)? = nil) {
        self.applicantID = applicantID
        self.repository = repository ?? BackendApplicationRepository()
    }

    var visibleApplications: [ApplicationRecord] {
        switch filter {
        case .all: applications
        case .active: applications.filter { ![.accepted, .rejected].contains($0.status) }
        case .accepted: applications.filter { $0.status == .accepted }
        }
    }

    func count(for filter: Filter) -> Int {
        switch filter {
        case .all: applications.count
        case .active: applications.filter { ![.accepted, .rejected].contains($0.status) }.count
        case .accepted: applications.filter { $0.status == .accepted }.count
        }
    }

    func load() async {
        guard !applicantID.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await repository.fetch(for: applicantID)
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось загрузить заявления. Проверьте интернет-соединение."
            )
        }
    }

    func create(
        institution: InstitutionRecord,
        specialty: SpecialtyRecord,
        studyForm: String,
        fundingType: String
    ) async throws {
        let nextPriority = (applications.map(\.priority).max() ?? 0) + 1
        let application = ApplicationRecord(
            applicantID: applicantID,
            institutionID: institution.id,
            institutionName: institution.name,
            specialtyID: specialty.id,
            specialtyName: specialty.name,
            studyForm: studyForm,
            fundingType: fundingType,
            priority: nextPriority
        )
        try await repository.save(application)
        applications.append(application)
        applications.sort { $0.priority < $1.priority }
    }

    func move(from source: IndexSet, to destination: Int) {
        let moved = source.sorted().map { applications[$0] }
        for index in source.sorted(by: >) {
            applications.remove(at: index)
        }
        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = max(0, min(destination - removedBeforeDestination, applications.count))
        applications.insert(contentsOf: moved, at: insertionIndex)
        for index in applications.indices {
            applications[index].priority = index + 1
            applications[index].updatedAt = .now
        }
    }

    func savePriorities() async throws {
        try await repository.replacePriorities(applications)
        applications = try await repository.fetch(for: applicantID)
    }
}
