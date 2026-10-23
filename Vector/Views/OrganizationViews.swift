import SwiftUI

struct OrganizationApplicationView: View {
    @State private var draft: OrganizationApplicationDraft
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let email: String
    let onSubmit: (OrganizationApplicationDraft) async throws -> Void
    let onCancel: () -> Void

    init(
        email: String,
        initialType: OrganizationType,
        onSubmit: @escaping (OrganizationApplicationDraft) async throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.email = email
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _draft = State(initialValue: OrganizationApplicationDraft(type: initialType))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OrganizationApplicationHeader(email: email)
                    OrganizationTypePicker(selection: $draft.type)
                    OrganizationApplicationFields(draft: $draft)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Отправить на проверку")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isSubmitting || !isValid)
                    .opacity(isSubmitting || !isValid ? 0.55 : 1)
                }
                .padding(24)
            }
            .background(.systemWhite)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
            }
        }
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.taxId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() async {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await onSubmit(draft)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OrganizationApplicationHeader: View {
    let email: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VECTOR / ОРГАНИЗАЦИЯ")
                .font(.caption.bold())
                .foregroundStyle(.systemBlue01)
            Text("Регистрация организации")
                .font(.largeTitle.bold())
                .foregroundStyle(.systemDarkBlue)
            Text("Заявка будет привязана к аккаунту \(email) и появится у администратора.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OrganizationTypePicker: View {
    @Binding var selection: OrganizationType

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Тип аккаунта")
                .font(.headline)
                .foregroundStyle(.systemDarkBlue)

            HStack(spacing: 12) {
                ForEach(OrganizationType.allCases) { type in
                    Button {
                        selection = type
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.title2)
                            Text(type.title)
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(selection == type ? .white : .systemDarkBlue)
                        .frame(maxWidth: .infinity, minHeight: 92)
                        .background(
                            selection == type ? Color.systemBlue01 : Color.systemBlue01.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct OrganizationApplicationFields: View {
    @Binding var draft: OrganizationApplicationDraft

    var body: some View {
        VStack(spacing: 14) {
            OrganizationField(title: "Название", text: $draft.name)
            OrganizationField(title: "Юридическое название", text: $draft.legalName)
            OrganizationField(title: "УНП", text: $draft.taxId)
                .textInputAutocapitalization(.characters)
            OrganizationField(title: "Город", text: $draft.city)
            OrganizationField(title: "Сайт (необязательно)", text: $draft.website)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            OrganizationField(
                title: "Краткое описание (необязательно)",
                text: $draft.description,
                axis: .vertical
            )
        }
    }
}

private struct OrganizationField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        TextField(title, text: $text, axis: axis)
            .lineLimit(axis == .vertical ? 3...6 : 1...1)
            .padding(16)
            .background(.systemBlue01.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.systemGrey1.opacity(0.35))
            }
    }
}

struct OrganizationRootView: View {
    let user: AuthenticatedUser
    let organization: OrganizationRecord?
    let onRefresh: () async -> Void
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OrganizationHeader(
                        title: organization?.name ?? "Организация",
                        type: organization?.type ?? roleType
                    )

                    if let organization {
                        OrganizationStatusCard(status: organization.status)

                        if organization.status == .active {
                            OrganizationWorkspace(organization: organization)
                        } else {
                            OrganizationReviewDetails(organization: organization)
                        }
                    } else {
                        ContentUnavailableView(
                            "Заявка не найдена",
                            systemImage: "building.2.crop.circle",
                            description: Text("Обновите данные или обратитесь в поддержку.")
                        )
                    }

                    Button("Обновить статус") {
                        Task { await onRefresh() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.systemBlue01)

                    Button("Выйти", role: .destructive, action: onSignOut)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .padding(24)
            }
            .background(.systemWhite)
            .refreshable { await onRefresh() }
        }
    }

    private var roleType: OrganizationType {
        user.role == .institution ? .institution : .employer
    }
}

private struct OrganizationHeader: View {
    let title: String
    let type: OrganizationType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VECTOR / \(type.title.uppercased())")
                .font(.caption.bold())
                .foregroundStyle(.systemBlue01)
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.systemDarkBlue)
            Text("Кабинет организации")
                .foregroundStyle(.secondary)
        }
    }
}

private struct OrganizationStatusCard: View {
    let status: OrganizationVerificationStatus

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }

    private var icon: String {
        switch status {
        case .pending: "clock"
        case .active: "checkmark.shield.fill"
        case .needsClarification: "questionmark.circle"
        case .rejected: "xmark.circle"
        }
    }

    private var color: Color {
        switch status {
        case .pending, .needsClarification: .orange
        case .active: .green
        case .rejected: .red
        }
    }

    private var message: String {
        switch status {
        case .pending: "Администратор проверяет сведения. Доступ откроется после подтверждения."
        case .active: "Доступ к функциям организации открыт."
        case .needsClarification: "Администратору нужны дополнительные сведения."
        case .rejected: "Проверьте данные и свяжитесь с поддержкой."
        }
    }
}

private struct OrganizationReviewDetails: View {
    let organization: OrganizationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(organization.city, systemImage: "mappin")
            Label("УНП: \(organization.taxId)", systemImage: "number")
            if !organization.website.isEmpty {
                Label(organization.website, systemImage: "globe")
            }
        }
        .foregroundStyle(.systemDarkBlue)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.systemBlue01.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct OrganizationWorkspace: View {
    let organization: OrganizationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Рабочее пространство")
                .font(.title2.bold())
                .foregroundStyle(.systemDarkBlue)
            if organization.type == .institution {
                NavigationLink {
                    OrganizationApplicationsView()
                } label: {
                    OrganizationWorkspaceRow(
                        icon: "doc.text",
                        title: "Заявления абитуриентов",
                        subtitle: "Проверка документов и решения"
                    )
                }
                .buttonStyle(.plain)
            } else {
                OrganizationWorkspaceRow(
                    icon: "briefcase",
                    title: "Вакансии",
                    subtitle: "Создание и управление вакансиями"
                )
            }
            OrganizationWorkspaceRow(
                icon: "person.2",
                title: "Сотрудники",
                subtitle: "Приглашения и роли"
            )
        }
    }
}

private struct OrganizationWorkspaceRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.systemBlue01)
                .frame(width: 44, height: 44)
                .background(.systemBlue01.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.systemWhite, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.systemGrey1.opacity(0.35))
        }
    }
}
