import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct RegistrationDateField: View {
    let title: String
    @Binding var date: Date?
    var errorMessage: String?

    private var dateBinding: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { date = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.systemBlue01)
                Text(title)
                    .foregroundStyle(.systemDarkBlue.opacity(0.6))
                Spacer()
                DatePicker(
                    "",
                    selection: dateBinding,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .onChange(of: dateBinding.wrappedValue) { _, newValue in
                    date = newValue
                }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(errorMessage == nil ? .systemGrey1 : .red)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 8)
            }
        }
    }
}

struct PersonalStepView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 18) {
            VectorTextField2(
                placeholder: "Фамилия",
                icon: "person",
                text: $model.profile.personal.lastName,
                errorMessage: model.errors["lastName"]
            )
            VectorTextField2(
                placeholder: "Имя",
                icon: "person",
                text: $model.profile.personal.firstName,
                errorMessage: model.errors["firstName"]
            )
            VectorTextField2(
                placeholder: "Отчество (необязательно)",
                icon: "person",
                text: $model.profile.personal.patronymic
            )
            RegistrationDateField(
                title: "Дата рождения",
                date: $model.profile.personal.birthDate,
                errorMessage: model.errors["birthDate"]
            )
        }
    }
}

struct ContactStepView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 18) {
            VectorTextField2(
                placeholder: "Email",
                icon: "envelope",
                text: $model.profile.contact.email,
                errorMessage: model.errors["email"],
                keyboardType: .emailAddress,
                capitalization: .never
            )
            VectorTextField2(
                placeholder: "Телефон",
                icon: "phone.fill",
                text: $model.profile.contact.phone,
                errorMessage: model.errors["phone"],
                keyboardType: .phonePad
            )
            VectorTextField2(
                placeholder: "Резервный телефон (необязательно)",
                icon: "phone.fill",
                text: $model.profile.contact.reservePhone,
                keyboardType: .phonePad
            )
        }
    }
}

struct PassportStepView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 18) {
            VectorTextField2(
                placeholder: "Серия и номер",
                icon: "person.text.rectangle",
                text: $model.profile.passport.seriesAndNumber,
                errorMessage: model.errors["passportNumber"],
                capitalization: .characters
            )
            VectorTextField2(
                placeholder: "Идентификационный номер",
                icon: "number",
                text: $model.profile.passport.identificationNumber,
                errorMessage: model.errors["identificationNumber"],
                capitalization: .characters
            )
            RegistrationDateField(
                title: "Дата выдачи",
                date: $model.profile.passport.issueDate,
                errorMessage: model.errors["issueDate"]
            )
            VectorTextField2(
                placeholder: "Кем выдан",
                icon: "building.columns",
                text: $model.profile.passport.issuedBy,
                errorMessage: model.errors["issuedBy"]
            )
        }
    }
}

struct AddressStepView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 18) {
            VectorPicker(
                title: "Страна",
                icon: "globe",
                options: GeographyCatalog.countries.map {
                    VectorPickerOption(id: $0.id, title: $0.name)
                },
                selection: Binding(
                    get: { model.profile.address.countryID },
                    set: { model.selectCountry($0) }
                ),
                errorMessage: model.errors["country"]
            )

            if model.selectedCountry?.regions.isEmpty == false {
                VectorPicker(
                    title: "Регион или административная единица",
                    icon: "map",
                    options: model.availableRegions.map {
                        VectorPickerOption(id: $0.id, title: $0.name)
                    },
                    selection: Binding(
                        get: { model.profile.address.regionID },
                        set: { model.selectRegion($0) }
                    ),
                    isDisabled: model.profile.address.countryID.isEmpty,
                    errorMessage: model.errors["region"]
                )

                VectorPicker(
                    title: "Город",
                    icon: "building.2",
                    options: model.availableCities.map {
                        VectorPickerOption(id: $0.id, title: $0.name)
                    },
                    selection: $model.profile.address.cityID,
                    isDisabled: model.profile.address.regionID.isEmpty,
                    errorMessage: model.errors["city"]
                )
            } else if !model.profile.address.countryID.isEmpty {
                Text("Справочник регионов для этой страны пока не подключён. Укажите адрес в строках ниже.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VectorTextField2(
                placeholder: "Улица",
                icon: "signpost.right",
                text: $model.profile.address.street,
                errorMessage: model.errors["street"]
            )
            HStack(alignment: .top, spacing: 12) {
                VectorTextField2(
                    placeholder: "Дом",
                    icon: "house",
                    text: $model.profile.address.house,
                    errorMessage: model.errors["house"]
                )
                VectorTextField2(
                    placeholder: "Квартира",
                    icon: nil,
                    text: $model.profile.address.apartment,
                    keyboardType: .numbersAndPunctuation
                )
            }
        }
    }
}

struct EducationStepView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(EducationStatus.allCases) { status in
                Button {
                    model.selectEducationStatus(status)
                } label: {
                    SelectionCard(
                        title: status.title,
                        icon: status.icon,
                        isSelected: model.profile.education.status == status
                    )
                }
                .buttonStyle(.plain)
            }

            if let error = model.errors["educationStatus"] {
                InlineErrorText(message: error)
            }

            if model.profile.education.status != nil {
                VectorTextField2(
                    placeholder: "Год окончания",
                    icon: "calendar",
                    text: Binding(
                        get: { model.profile.education.graduationYear.map(String.init) ?? "" },
                        set: { model.profile.education.graduationYear = Int($0.filter(\.isNumber)) }
                    ),
                    errorMessage: model.errors["graduationYear"],
                    keyboardType: .numberPad
                )
                .padding(.top, 6)
            }
        }
    }
}

struct InstitutionStepView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 18) {
            if !model.availableInstitutions.isEmpty {
                Menu {
                    ForEach(model.availableInstitutions) { institution in
                        Button("\(institution.name), \(institution.locality)") {
                            model.selectInstitution(institution)
                        }
                    }
                } label: {
                    Label("Выбрать из локального списка", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.systemBlue01)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(.systemBlue01.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
            }

            VectorTextField2(
                placeholder: model.profile.education.status?.institutionLabel ?? "Учебное заведение",
                icon: "building.2",
                text: $model.profile.institution.name,
                errorMessage: model.errors["institution"]
            )
            VectorTextField2(
                placeholder: "Населённый пункт",
                icon: "mappin.and.ellipse",
                text: $model.profile.institution.locality,
                errorMessage: model.errors["institutionLocality"]
            )
            VectorTextField2(
                placeholder: "Профильный класс (необязательно)",
                icon: "book",
                text: $model.profile.institution.profileClass
            )

            Text("Локальный список демонстрационный и подготовлен для замены реальным справочником.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DocumentsStepView: View {
    @Bindable var model: RegistrationViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingDocumentKind: DocumentKind?
    @State private var isPhotoPickerPresented = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(model.profile.documents) { document in
                DocumentCard(
                    document: document,
                    errorMessage: model.errors["document-\(document.kind.rawValue)"],
                    onSelect: {
                        pendingDocumentKind = document.kind
                        isPhotoPickerPresented = true
                    },
                    onRemove: {
                        Task { await model.removeDocument(kind: document.kind) }
                    },
                    onRecheck: {
                        Task { await model.recheckDocument(kind: document.kind) }
                    }
                )
            }

            Text("Фотографии сохраняются только на этом устройстве и не отправляются на сервер.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhoto,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto,
                  let kind = pendingDocumentKind else {
                return
            }

            Task {
                defer {
                    selectedPhoto = nil
                    pendingDocumentKind = nil
                }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        model.markDocumentError(
                            kind: kind,
                            message: "Не удалось прочитать выбранную фотографию."
                        )
                        return
                    }
                    let contentType = item.supportedContentTypes.first ?? .jpeg
                    await model.saveDocumentPhoto(
                        kind: kind,
                        data: data,
                        fileExtension: contentType.preferredFilenameExtension ?? "jpg",
                        mimeType: contentType.preferredMIMEType ?? "image/jpeg"
                    )
                } catch {
                    model.markDocumentError(kind: kind, message: error.localizedDescription)
                }
            }
        }
        .task { await model.restoreLocalDocuments() }
    }
}

struct DocumentCard: View {
    let document: ProfileDocument
    let errorMessage: String?
    let onSelect: () -> Void
    let onRemove: () -> Void
    let onRecheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: document.kind.icon)
                    .font(.title3)
                    .foregroundStyle(.systemBlue01)
                    .frame(width: 42, height: 42)
                    .background(.systemBlue01.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.kind.title)
                        .font(.headline)
                        .foregroundStyle(.systemDarkBlue)
                    Text(document.kind.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DocumentStatusBadge(document: document)
            }

            if let fileName = document.fileName {
                if let localURL = document.localURL {
                    LocalDocumentPreview(url: localURL)
                }
                Text(fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.systemDarkBlue)

                HStack {
                    Button("Заменить", action: onSelect)
                    Spacer()
                    Button("Удалить", role: .destructive, action: onRemove)
                }
                .font(.subheadline.weight(.semibold))

                if let verification = document.verification {
                    DocumentVerificationView(
                        verification: verification,
                        onRecheck: onRecheck
                    )
                }
            } else {
                Button("Выбрать фотографию", action: onSelect)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.systemBlue01)
            }

            if let message = document.errorMessage ?? errorMessage {
                InlineErrorText(message: message)
            }
        }
        .padding(16)
        .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(errorMessage == nil ? .systemGrey1.opacity(0.7) : .red)
        }
    }
}

private struct DocumentVerificationView: View {
    let verification: DocumentVerification
    let onRecheck: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                switch verification.status {
                case .checking:
                    ProgressView()
                    Text("Проверяем фотографию…")
                case .likelyMatches:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Документ похож на выбранный тип")
                case .needsReview:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Требуется дополнительная проверка")
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Не удалось выполнить проверку")
                }
                Spacer()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.systemDarkBlue)

            if verification.status != .checking {
                DisclosureGroup("Результаты проверки", isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(verification.matchedChecks, id: \.self) { check in
                            Label(check, systemImage: "checkmark")
                                .foregroundStyle(.green)
                        }
                        ForEach(verification.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        Text("Это автоматическая предварительная проверка, а не подтверждение подлинности.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 3)
                    }
                    .font(.caption)
                    .padding(.top, 8)
                }

                Button("Проверить повторно", action: onRecheck)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.systemBlue01)
            }
        }
        .padding(12)
        .background(.systemBlue01.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct LocalDocumentPreview: View {
    let url: URL

    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Предпросмотр выбранного документа")
        }
    }
}

struct DocumentStatusBadge: View {
    let document: ProfileDocument

    var body: some View {
        Text(statusText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.1), in: Capsule())
    }

    private var statusText: String {
        switch document.status {
        case .notSelected: "Не загружено"
        case .selected: "Выбран файл"
        case .uploading: "Сохраняется"
        case .uploaded: "Сохранено локально"
        case .failed: "Ошибка"
        }
    }

    private var statusColor: Color {
        switch document.status {
        case .notSelected: .secondary
        case .selected: .systemBlue01
        case .uploading: .orange
        case .uploaded: .green
        case .failed: .red
        }
    }
}

struct ExamResultsStepView: View {
    @Bindable var model: RegistrationViewModel

    private let subjects = [
        "Белорусский язык", "Русский язык", "Математика", "Физика",
        "Химия", "Биология", "История Беларуси", "Обществоведение",
        "География", "Иностранный язык"
    ]

    var body: some View {
        VStack(spacing: 14) {
            if model.profile.examResults.isEmpty {
                EmptyHint(
                    icon: "checkmark.seal",
                    text: "Добавьте результат, если уже сдавали ЦЭ или ЦТ."
                )
            }

            ForEach($model.profile.examResults) { $result in
                VStack(spacing: 12) {
                    VectorPicker(
                        title: "Предмет",
                        icon: "book.closed",
                        options: subjects.map { VectorPickerOption(id: $0, title: $0) },
                        selection: $result.subject,
                        errorMessage: model.errors["exam-\(result.id)-subject"]
                    )
                    VectorTextField2(
                        placeholder: "Балл (\(ExamRules.minimumScore)–\(ExamRules.maximumScore))",
                        icon: "number",
                        text: $result.score,
                        errorMessage: model.errors["exam-\(result.id)-score"],
                        keyboardType: .numberPad
                    )
                    Button(role: .destructive) {
                        model.removeExamResult(id: result.id)
                    } label: {
                        Label("Удалить результат", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(14)
                .background(.systemBlue01.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            }

            Button {
                model.addExamResult()
            } label: {
                Label("Добавить предмет", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.systemBlue01)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.systemBlue01)
                    }
            }
        }
    }
}

struct AchievementsStepView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach($model.profile.achievements) { $achievement in
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $achievement.isIncluded) {
                        Label(achievement.category.title, systemImage: achievement.category.icon)
                            .font(.headline)
                            .foregroundStyle(.systemDarkBlue)
                    }
                    .tint(.systemBlue01)

                    if achievement.isIncluded {
                        Stepper(
                            "Количество: \(achievement.count)",
                            value: $achievement.count,
                            in: 1...99
                        )
                        VectorTextField2(
                            placeholder: "Описание (необязательно)",
                            icon: "text.alignleft",
                            text: $achievement.details
                        )
                        if let error = model.errors["achievement-\(achievement.category.rawValue)"] {
                            InlineErrorText(message: error)
                        }
                    }
                }
                .padding(16)
                .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.systemGrey1.opacity(0.7))
                }
            }
        }
    }
}

struct AdditionalStepView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 18) {
            VectorTextField2(
                placeholder: "Гражданство",
                icon: "globe.europe.africa",
                text: $model.profile.additional.citizenship,
                errorMessage: model.errors["citizenship"]
            )

            VStack(spacing: 0) {
                Toggle("Нуждаюсь в общежитии", isOn: $model.profile.additional.needsDormitory)
                    .padding(.vertical, 14)
                Divider()
                Toggle("Целевое обучение", isOn: $model.profile.additional.targetEducation)
                    .padding(.vertical, 14)
            }
            .tint(.systemBlue01)
            .padding(.horizontal, 16)
            .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.systemGrey1.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Комментарий (необязательно)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $model.profile.additional.comment)
                    .frame(minHeight: 110)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(.systemWhite)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.systemGrey1)
                    }
            }
        }
    }
}

struct SelectionCard: View {
    let title: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .systemBlue01)
                .frame(width: 44, height: 44)
                .background(isSelected ? .systemBlue01 : .systemBlue01.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
            Text(title)
                .font(.headline)
                .foregroundStyle(.systemDarkBlue)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .systemBlue01 : .systemGrey1)
        }
        .padding(16)
        .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? .systemBlue01 : .systemGrey1, lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }
}

struct InlineErrorText: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.systemBlue01.opacity(0.7))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.systemBlue01.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}
