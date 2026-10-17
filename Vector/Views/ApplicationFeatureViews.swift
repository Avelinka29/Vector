import SwiftUI

struct NewApplicationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var catalog = SpecialtiesViewModel()
    @State private var institutionType = "university"
    @State private var institutionID: String?
    @State private var specialtyID: String?
    @State private var studyForm = "fullTime"

    var body: some View {
        Form {
            Section {
                Picker("Тип учреждения", selection: $institutionType) {
                    Text("Университет").tag("university")
                    Text("Колледж").tag("college")
                }
                .pickerStyle(.inline)
            } header: {
                Text("Шаг 1 из 5")
            }

            Section("Учебное заведение") {
                Picker("Выберите учреждение", selection: $institutionID) {
                    Text("Не выбрано").tag(String?.none)
                    ForEach(
                        catalog.institutions.filter { $0.type == institutionType }
                    ) { institution in
                        Text(institution.name).tag(Optional(institution.id))
                    }
                }
            }

            Section("Специальность") {
                Picker("Выберите специальность", selection: $specialtyID) {
                    Text("Не выбрано").tag(String?.none)
                    ForEach(
                        catalog.specialties.filter { $0.institutionID == institutionID }
                    ) { specialty in
                        Text(specialty.name).tag(Optional(specialty.id))
                    }
                }
                .disabled(institutionID == nil)
            }

            Section("Форма обучения") {
                Picker("Форма обучения", selection: $studyForm) {
                    Text("Очная").tag("fullTime")
                    Text("Заочная").tag("partTime")
                }
            }

            Section {
                Button("Продолжить") {}
                    .frame(maxWidth: .infinity)
                    .disabled(institutionID == nil || specialtyID == nil)
            } footer: {
                Text("Отправка заявлений станет доступна после подключения приёмных кампаний.")
            }
        }
        .navigationTitle("Новое заявление")
        .navigationBarTitleDisplayMode(.inline)
        .task { await catalog.load() }
        .onChange(of: institutionType) {
            institutionID = nil
            specialtyID = nil
        }
        .onChange(of: institutionID) {
            specialtyID = nil
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") { dismiss() }
            }
        }
    }
}

struct PrioritiesView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Приоритеты не выбраны", systemImage: "list.number")
        } description: {
            Text("Здесь можно будет расставить отправленные заявления в порядке приоритета.")
        }
        .navigationTitle("Приоритеты")
    }
}

struct AnalyticsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Аналитика пока недоступна", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Проходные баллы и конкурс появятся после подключения официальных данных приёмных кампаний.")
        }
        .navigationTitle("Аналитика")
    }
}

struct NotificationsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Уведомлений пока нет", systemImage: "bell")
        } description: {
            Text("Здесь появятся изменения статусов заявлений и важные сообщения.")
        }
        .navigationTitle("Уведомления")
    }
}
