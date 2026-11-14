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
                    OrganizationApplicationHeader(email: email, type: draft.type)
                    OrganizationAccountTypeCard(type: draft.type)

                    if draft.type == .institution {
                        InstitutionApplicationFields(draft: $draft, email: email)
                    } else {
                        OrganizationApplicationFields(draft: $draft)
                    }

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
        let baseFieldsAreValid =
            !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.taxId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard draft.type == .institution else { return baseFieldsAreValid }

        let taxID = draft.taxId.trimmingCharacters(in: .whitespacesAndNewlines)
        return baseFieldsAreValid
            && taxID.count == 9
            && taxID.allSatisfy(\.isNumber)
            && !draft.legalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    let type: OrganizationType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(type == .institution ? "РЕГИСТРАЦИЯ УЧРЕЖДЕНИЯ" : "РЕГИСТРАЦИЯ РАБОТОДАТЕЛЯ")
                .font(.caption.bold())
                .foregroundStyle(.systemBlue01)
            Text(type == .institution ? "Расскажите об учреждении" : "Расскажите об организации")
                .font(.largeTitle.bold())
                .foregroundStyle(.systemDarkBlue)
            Text("Заявка будет привязана к аккаунту \(email) и появится у администратора.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OrganizationAccountTypeCard: View {
    let type: OrganizationType

    var body: some View {
        Label(type.title, systemImage: type.icon)
            .font(.headline)
            .foregroundStyle(.systemBlue01)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct InstitutionApplicationFields: View {
    @Binding var draft: OrganizationApplicationDraft
    let email: String

    private let institutionTypes = [
        "Университет",
        "Академия",
        "Институт",
        "Колледж",
        "Другое учреждение"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Об учреждении")
                .font(.title2.bold())
                .foregroundStyle(.systemDarkBlue)

            OrganizationField(title: "Краткое название", text: $draft.name)

            VStack(alignment: .leading, spacing: 8) {
                Text("Тип учреждения")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.systemDarkBlue)

                Picker("Тип учреждения", selection: $draft.institutionType) {
                    ForEach(institutionTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(.systemBlue01)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .background(.systemBlue01.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.systemGrey1.opacity(0.35))
                }
            }

            OrganizationField(title: "Полное название учреждения", text: $draft.legalName)
            OrganizationField(title: "УНП — 9 цифр", text: $draft.taxId)
                .keyboardType(.numberPad)
                .onChange(of: draft.taxId) { _, newValue in
                    draft.taxId = String(newValue.filter(\.isNumber).prefix(9))
                }
            OrganizationField(title: "Город", text: $draft.city)
            OrganizationField(title: "Адрес учреждения", text: $draft.address)

            Text("Ответственный сотрудник")
                .font(.title2.bold())
                .foregroundStyle(.systemDarkBlue)
                .padding(.top, 4)

            OrganizationField(title: "Имя и фамилия ответственного", text: $draft.contactName)

            LabeledContent("Рабочий email") {
                Text(email)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
            .padding(16)
            .background(.systemBlue01.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))

            OrganizationField(title: "Контактный телефон", text: $draft.phone)
                .keyboardType(.phonePad)
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

                    NavigationLink("Вход и email") {
                        AccountConnectionsView()
                    }
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
                NavigationLink {
                    EmployerWorkspaceView()
                } label: {
                    OrganizationWorkspaceRow(
                        icon: "briefcase",
                        title: "Вакансии, отклики и сотрудники",
                        subtitle: "Полное управление кабинетом работодателя"
                    )
                }
                .buttonStyle(.plain)
            }
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
