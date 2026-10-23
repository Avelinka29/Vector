import Observation
import SwiftUI

@MainActor
@Observable
final class OrganizationModerationViewModel {
    var organizations: [OrganizationRecord] = []
    var isLoading = false
    var errorMessage: String?

    private let service = OrganizationService()

    var pendingOrganizations: [OrganizationRecord] {
        organizations.filter {
            $0.status == .pending || $0.status == .needsClarification
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            organizations = try await service.loadForModeration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setStatus(
        _ status: OrganizationVerificationStatus,
        for organization: OrganizationRecord
    ) async throws {
        let updated = try await service.updateStatus(
            organizationID: organization.id,
            status: status
        )
        if let index = organizations.firstIndex(where: { $0.id == organization.id }) {
            organizations[index] = updated
        }
    }
}

struct AdminOrganizationApplicationCard: View {
    let organization: OrganizationRecord

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: organization.type.icon)
                .font(.title2)
                .foregroundStyle(.systemBlue01)
                .frame(width: 52, height: 52)
                .background(Color.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(organization.name)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                Text(organization.type.title + (organization.city.isEmpty ? "" : " · " + organization.city))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(organization.status.title)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.systemDarkBlue.opacity(0.1))
        }
    }
}

struct AdminOrganizationApplicationReviewView: View {
    let organization: OrganizationRecord
    let onStatusChange: (OrganizationVerificationStatus) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Проверка организации")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.systemDarkBlue)
                    Text(organization.type.title)
                        .foregroundStyle(.secondary)
                }

                detail("Название", organization.name, icon: organization.type.icon)
                detail("Юридическое название", organization.legalName, icon: "doc.text")
                detail("УНП", organization.taxId, icon: "number")
                detail("Город", organization.city, icon: "mappin.and.ellipse")
                detail("Сайт", organization.website, icon: "globe")

                if !organization.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Описание")
                            .font(.headline)
                            .foregroundStyle(.systemDarkBlue)
                        Text(organization.description)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                actionButton("Подтвердить организацию", status: .active, filled: true)
                actionButton("Вернуть на уточнение", status: .needsClarification, filled: false)
                actionButton("Отклонить заявку", status: .rejected, filled: false)
                    .tint(.red)
            }
            .padding(24)
        }
        .background(.systemWhite)
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView("Сохраняем решение…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func detail(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.systemBlue01)
                .frame(width: 42, height: 42)
                .background(Color.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.isEmpty ? "Не указано" : value)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.systemDarkBlue.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private func actionButton(
        _ title: String,
        status: OrganizationVerificationStatus,
        filled: Bool
    ) -> some View {
        Button {
            Task {
                isSaving = true
                errorMessage = nil
                do {
                    try await onStatusChange(status)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isSaving = false
            }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(filled ? .white : Color.systemBlue01)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    filled ? Color.systemBlue01 : Color.clear,
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .overlay {
                    if !filled {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.systemBlue01, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
