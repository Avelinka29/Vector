import SwiftUI

struct DocumentsOverviewView: View {
    let documents: [ProfileDocument]
    let onEditDocuments: () -> Void

    init(
        documents: [ProfileDocument],
        onEditDocuments: @escaping () -> Void = {}
    ) {
        self.documents = documents
        self.onEditDocuments = onEditDocuments
    }

    var body: some View {
        List {
            Section {
                ForEach(displayedDocuments) { document in
                    HStack(spacing: 14) {
                        Image(systemName: document.kind.icon)
                            .foregroundStyle(.systemDarkBlue)
                            .frame(width: 38, height: 38)
                            .background(.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(document.kind.title)
                                .font(.headline)
                                .foregroundStyle(.systemDarkBlue)
                            Text(documentStatus(document))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Image(systemName: statusIcon(document.status))
                            .foregroundStyle(statusColor(document.status))
                    }
                    .padding(.vertical, 5)
                }
            } header: {
                Text("Все документы")
            } footer: {
                Label(
                    "Документы необязательны и станут доступны учреждениям только после отдельной отправки.",
                    systemImage: "info.circle"
                )
            }
        }
        .navigationTitle("Документы")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(action: onEditDocuments) {
                Label("Добавить или изменить", systemImage: "plus")
            }
        }
    }

    private var displayedDocuments: [ProfileDocument] {
        documents.isEmpty
            ? DocumentKind.allCases.map { ProfileDocument(kind: $0) }
            : documents
    }

    private func documentStatus(_ document: ProfileDocument) -> String {
        switch document.status {
        case .notSelected: "Не выбран"
        case .selected: "Выбран файл"
        case .uploading: "Сохраняется"
        case .uploaded: "Сохранён локально"
        case .failed: "Ошибка"
        }
    }

    private func statusIcon(_ status: DocumentTransferStatus) -> String {
        switch status {
        case .uploaded: "checkmark.circle.fill"
        case .selected, .uploading: "clock.fill"
        case .failed: "exclamationmark.circle.fill"
        case .notSelected: "circle"
        }
    }

    private func statusColor(_ status: DocumentTransferStatus) -> Color {
        switch status {
        case .uploaded: .green
        case .selected, .uploading: .orange
        case .failed: .red
        case .notSelected: .secondary
        }
    }
}

struct DigitalProfileView: View {
    let profile: ApplicantProfile
    let onEditProfile: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CompletionRing(percentage: profile.completionPercentage)

                VStack(spacing: 0) {
                    ProfileSummaryRow(
                        title: "Личные данные",
                        subtitle: profile.personal.firstName.isEmpty ? "Не заполнено" : "Заполнено",
                        icon: "person"
                    )
                    Divider()
                    ProfileSummaryRow(
                        title: "Документы",
                        subtitle: "\(profile.documents.filter { $0.status != .notSelected }.count) из \(profile.documents.count) выбрано",
                        icon: "doc.text"
                    )
                    Divider()
                    ProfileSummaryRow(
                        title: "Достижения",
                        subtitle: "\(profile.achievements.filter(\.isIncluded).count) категорий заполнено",
                        icon: "trophy"
                    )
                    Divider()
                    ProfileSummaryRow(
                        title: "Предпочтения",
                        subtitle: profile.additional.citizenship.isEmpty ? "Не заполнено" : "Заполнено",
                        icon: "slider.horizontal.3"
                    )
                }
                .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.systemGrey1.opacity(0.35))
                }

                Button("Продолжить заполнение", action: onEditProfile)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(20)
        }
        .background(Color.systemBlue01.opacity(0.035))
        .navigationTitle("Цифровой профиль")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CompletionRing: View {
    let percentage: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(.systemGrey1.opacity(0.25), lineWidth: 8)
            Circle()
                .trim(from: 0, to: Double(percentage) / 100)
                .stroke(.systemBlue01, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percentage)%")
                .font(.title.bold())
                .foregroundStyle(.systemDarkBlue)
        }
        .frame(width: 132, height: 132)
        .accessibilityLabel("Профиль заполнен на \(percentage) процентов")
    }
}

struct ProfileSummaryRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.systemBlue01)
                .frame(width: 34, height: 34)
                .background(.systemBlue01.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.systemDarkBlue)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}
