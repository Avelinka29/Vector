import SwiftUI

struct NewApplicationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var institutionType = "university"
    @State private var institutionName = ""
    @State private var specialtyName = ""
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
                TextField("Выберите учреждение", text: $institutionName)
            }

            Section("Специальность") {
                TextField("Выберите специальность", text: $specialtyName)
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
                    .disabled(institutionName.isEmpty || specialtyName.isEmpty)
            } footer: {
                Text("Отправка заявлений станет доступна после подключения приёмных кампаний.")
            }
        }
        .navigationTitle("Новое заявление")
        .navigationBarTitleDisplayMode(.inline)
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
