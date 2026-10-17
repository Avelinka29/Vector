import SwiftUI

struct AdminDashboardView: View {
    let user: AuthenticatedUser
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Администратор", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.systemBlue01)
                    LabeledContent("Аккаунт", value: user.email)
                }

                Section("Управление") {
                    NavigationLink {
                        InstitutionManagementView()
                    } label: {
                        Label("Учебные заведения", systemImage: "building.columns")
                    }
                }

                Section {
                    Button("Выйти", role: .destructive, action: onSignOut)
                }
            }
            .navigationTitle("Панель администратора")
        }
    }
}

struct InstitutionManagementView: View {
    @State private var model = AdminInstitutionsViewModel()
    @State private var editingInstitution: InstitutionRecord?

    var body: some View {
        List {
            if model.isLoading && model.institutions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
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
            Button {
                editingInstitution = InstitutionRecord()
            } label: {
                Label("Добавить", systemImage: "plus")
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
