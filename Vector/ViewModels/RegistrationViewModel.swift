import Foundation
import Observation

@MainActor
@Observable
final class RegistrationViewModel {
    static let totalSteps = 10

    var currentStep = 1
    var profile: ApplicantProfile
    var errors: [String: String] = [:]
    var isSaving = false
    var saveError: String?
    var isComplete = false
    var activeDocumentKind: DocumentKind?

    private let repository: any ProfileRepository
    private let accountRepository: (any UserAccountRepository)?
    private let userID: String?
    private let localDocumentStorage = LocalDocumentStorage()
    private let documentRecognitionService = DocumentRecognitionService()
    private let onProfileSaved: ((ApplicantProfile) -> Void)?

    init(
        profile: ApplicantProfile? = nil,
        currentStep: Int = 1,
        repository: (any ProfileRepository)? = nil,
        accountRepository: (any UserAccountRepository)? = nil,
        userID: String? = nil,
        onProfileSaved: ((ApplicantProfile) -> Void)? = nil
    ) {
        self.profile = profile ?? ApplicantProfile()
        self.currentStep = min(max(currentStep, 1), Self.totalSteps)
        self.repository = repository ?? LocalProfileRepository(userID: userID ?? "guest")
        self.accountRepository = accountRepository
        self.userID = userID
        self.onProfileSaved = onProfileSaved
    }

    var title: String {
        switch currentStep {
        case 1: "Личные данные"
        case 2: "Контактная информация"
        case 3: "Паспортные данные"
        case 4: "Адрес проживания"
        case 5: "Образование"
        case 6: "Учебное заведение"
        case 7: "Документы"
        case 8: "Результаты ЦЭ / ЦТ"
        case 9: "Достижения"
        case 10: "Дополнительная информация"
        default: ""
        }
    }

    var subtitle: String {
        switch currentStep {
        case 1: "Укажите основную информацию о себе"
        case 2: "Как с вами можно связаться"
        case 3: "Укажите данные документа, удостоверяющего личность"
        case 4: "Страна, регион, город и точный адрес"
        case 5: "Выберите ваш текущий образовательный статус"
        case 6: "Укажите учебное заведение и населённый пункт"
        case 7: "Выберите локальные файлы документов"
        case 8: "Добавьте предметы и полученные баллы"
        case 9: "Расскажите о достижениях, если они есть"
        case 10: "Последние сведения перед созданием профиля"
        default: ""
        }
    }

    var selectedCountry: Country? {
        GeographyCatalog.country(id: profile.address.countryID)
    }

    var selectedRegion: Region? {
        GeographyCatalog.region(
            id: profile.address.regionID,
            countryID: profile.address.countryID
        )
    }

    var availableRegions: [Region] {
        selectedCountry?.regions ?? []
    }

    var availableCities: [City] {
        selectedRegion?.cities ?? []
    }

    var availableInstitutions: [InstitutionOption] {
        guard let status = profile.education.status else { return [] }
        return InstitutionCatalog.samples.filter { $0.supportedStatuses.contains(status) }
    }

    func selectCountry(_ id: String) {
        guard profile.address.countryID != id else { return }
        profile.address.countryID = id
        profile.address.regionID = ""
        profile.address.cityID = ""
        clearAddressErrors()
    }

    func selectRegion(_ id: String) {
        guard profile.address.regionID != id else { return }
        profile.address.regionID = id
        profile.address.cityID = ""
        errors["region"] = nil
        errors["city"] = nil
    }

    func selectEducationStatus(_ status: EducationStatus) {
        guard profile.education.status != status else { return }
        profile.education.status = status
        profile.education.graduationYear = nil
        profile.institution = InstitutionData()
        errors["educationStatus"] = nil
        errors["graduationYear"] = nil
    }

    func selectInstitution(_ option: InstitutionOption) {
        profile.institution.name = option.name
        profile.institution.locality = option.locality
        errors["institution"] = nil
        errors["institutionLocality"] = nil
    }

    func addExamResult() {
        profile.examResults.append(ExamResult())
    }

    func removeExamResult(id: UUID) {
        profile.examResults.removeAll { $0.id == id }
    }

    func saveDocumentPhoto(
        kind: DocumentKind,
        data: Data,
        fileExtension: String,
        mimeType: String
    ) async {
        guard let index = profile.documents.firstIndex(where: { $0.kind == kind }) else { return }
        profile.documents[index].status = .uploading
        profile.documents[index].errorMessage = nil

        do {
            let stored = try await localDocumentStorage.saveImage(
                data: data,
                fileExtension: fileExtension,
                mimeType: mimeType,
                userID: userID ?? "guest",
                kind: kind
            )
            profile.documents[index].fileName = stored.fileName
            profile.documents[index].localURL = stored.url
            profile.documents[index].mimeType = stored.mimeType
            profile.documents[index].fileSize = stored.byteCount
            profile.documents[index].selectedAt = Date()
            profile.documents[index].status = .uploaded
            profile.documents[index].verification = DocumentVerification(
                status: .checking,
                confidence: 0,
                matchedChecks: [],
                warnings: [],
                checkedAt: nil
            )
            errors["document-\(kind.rawValue)"] = nil

            await verifyDocument(kind: kind, data: data)
        } catch {
            profile.documents[index].status = .failed
            profile.documents[index].errorMessage = error.localizedDescription
        }
    }

    func removeDocument(kind: DocumentKind) async {
        guard let index = profile.documents.firstIndex(where: { $0.kind == kind }) else { return }
        let fileName = profile.documents[index].fileName
        do {
            try await localDocumentStorage.delete(
                fileName: fileName,
                userID: userID ?? "guest"
            )
        } catch {
            profile.documents[index].errorMessage = "Не удалось удалить локальный файл."
            return
        }
        profile.documents[index].fileName = nil
        profile.documents[index].localURL = nil
        profile.documents[index].mimeType = nil
        profile.documents[index].fileSize = nil
        profile.documents[index].selectedAt = nil
        profile.documents[index].verification = nil
        profile.documents[index].status = .notSelected
        profile.documents[index].errorMessage = nil
    }

    func restoreLocalDocuments() async {
        for index in profile.documents.indices {
            guard let fileName = profile.documents[index].fileName else { continue }
            do {
                if let url = try await localDocumentStorage.existingURL(
                    fileName: fileName,
                    userID: userID ?? "guest"
                ) {
                    profile.documents[index].localURL = url
                    profile.documents[index].status = .uploaded
                } else {
                    profile.documents[index].localURL = nil
                    profile.documents[index].status = .notSelected
                    profile.documents[index].verification = nil
                    profile.documents[index].errorMessage =
                        "Файл хранится только на устройстве и здесь не найден."
                }
            } catch {
                profile.documents[index].errorMessage = error.localizedDescription
            }
        }
    }

    func recheckDocument(kind: DocumentKind) async {
        guard let document = profile.documents.first(where: { $0.kind == kind }),
              let url = document.localURL else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            await verifyDocument(kind: kind, data: data)
        } catch {
            markVerificationFailed(kind: kind, message: "Не удалось прочитать локальную фотографию.")
        }
    }

    private func verifyDocument(kind: DocumentKind, data: Data) async {
        guard let index = profile.documents.firstIndex(where: { $0.kind == kind }) else { return }
        profile.documents[index].verification = DocumentVerification(
            status: .checking,
            confidence: 0,
            matchedChecks: [],
            warnings: [],
            checkedAt: nil
        )

        do {
            let expected = ExpectedDocumentData(
                firstName: profile.personal.firstName,
                lastName: profile.personal.lastName,
                patronymic: profile.personal.patronymic,
                firstNameLatin: profile.personal.firstNameLatin,
                lastNameLatin: profile.personal.lastNameLatin,
                patronymicLatin: profile.personal.patronymicLatin,
                birthDate: profile.personal.birthDate,
                passportNumber: profile.passport.seriesAndNumber
            )
            profile.documents[index].verification = try await documentRecognitionService.verify(
                imageData: data,
                kind: kind,
                expected: expected
            )
        } catch {
            markVerificationFailed(kind: kind, message: error.localizedDescription)
        }
    }

    private func markVerificationFailed(kind: DocumentKind, message: String) {
        guard let index = profile.documents.firstIndex(where: { $0.kind == kind }) else { return }
        profile.documents[index].verification = DocumentVerification(
            status: .failed,
            confidence: 0,
            matchedChecks: [],
            warnings: [message],
            checkedAt: Date()
        )
    }

    func markDocumentError(kind: DocumentKind, message: String) {
        guard let index = profile.documents.firstIndex(where: { $0.kind == kind }) else { return }
        profile.documents[index].status = .failed
        profile.documents[index].errorMessage = message
    }

    func goBack() {
        errors.removeAll()
        if currentStep > 1 {
            currentStep -= 1
        }
    }

    func advance() async {
        guard validateCurrentStep() else { return }

        if currentStep < Self.totalSteps {
            let nextStep = currentStep + 1
            guard await saveDraft(currentStep: nextStep) else { return }
            currentStep = nextStep
            errors.removeAll()
            return
        }

        await save()
    }

    func validateCurrentStep() -> Bool {
        errors.removeAll()

        switch currentStep {
        case 1: validatePersonal()
        case 2: validateContact()
        case 3: validatePassport()
        case 4: validateAddress()
        case 5: validateEducation()
        case 6: validateInstitution()
        case 7: validateDocuments()
        case 8: validateExamResults()
        case 9: validateAchievements()
        case 10: validateAdditional()
        default: break
        }

        return errors.isEmpty
    }

    private func validatePersonal() {
        require(profile.personal.lastName, key: "lastName", message: "Укажите фамилию.")
        require(profile.personal.firstName, key: "firstName", message: "Укажите имя.")
        requireLatinName(
            profile.personal.lastNameLatin,
            key: "lastNameLatin",
            message: "Укажите фамилию латиницей как в паспорте."
        )
        requireLatinName(
            profile.personal.firstNameLatin,
            key: "firstNameLatin",
            message: "Укажите имя латиницей как в паспорте."
        )
        if let patronymicLatin = profile.personal.patronymicLatin,
           !patronymicLatin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requireLatinName(
                patronymicLatin,
                key: "patronymicLatin",
                message: "Используйте для отчества только латинские буквы."
            )
        }
        if profile.personal.birthDate == nil {
            errors["birthDate"] = "Укажите дату рождения."
        }
    }

    private func requireLatinName(_ value: String?, key: String, message: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty,
              trimmed.range(of: "^[A-Za-z][A-Za-z '\\-]*$", options: .regularExpression) != nil else {
            errors[key] = message
            return
        }
    }

    private func validateContact() {
        let email = profile.contact.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.contains("@") || !email.contains(".") {
            errors["email"] = "Введите корректный email."
        }
        let phoneDigits = profile.contact.phone.filter(\.isNumber)
        if phoneDigits.count < 9 {
            errors["phone"] = "Введите корректный номер телефона."
        }
    }

    private func validatePassport() {
        require(profile.passport.seriesAndNumber, key: "passportNumber", message: "Укажите серию и номер.")
        require(profile.passport.identificationNumber, key: "identificationNumber", message: "Укажите идентификационный номер.")
        if profile.passport.issueDate == nil {
            errors["issueDate"] = "Укажите дату выдачи."
        }
        require(profile.passport.issuedBy, key: "issuedBy", message: "Укажите, кем выдан документ.")
    }

    private func validateAddress() {
        require(profile.address.countryID, key: "country", message: "Выберите страну.")
        if selectedCountry?.regions.isEmpty == false {
            require(profile.address.regionID, key: "region", message: "Выберите регион.")
            require(profile.address.cityID, key: "city", message: "Выберите город.")
        }
        require(profile.address.street, key: "street", message: "Укажите улицу.")
        require(profile.address.house, key: "house", message: "Укажите дом.")
    }

    private func validateEducation() {
        guard profile.education.status != nil else {
            errors["educationStatus"] = "Выберите образовательный статус."
            return
        }
        guard let year = profile.education.graduationYear else {
            errors["graduationYear"] = "Укажите год окончания."
            return
        }
        let currentYear = Calendar.current.component(.year, from: Date())
        if !(currentYear - 80...currentYear + 10).contains(year) {
            errors["graduationYear"] = "Укажите год в диапазоне \(currentYear - 80)–\(currentYear + 10)."
        }
    }

    private func validateInstitution() {
        require(profile.institution.name, key: "institution", message: "Укажите учебное заведение.")
        require(profile.institution.locality, key: "institutionLocality", message: "Укажите населённый пункт.")
    }

    private func validateDocuments() {
        for document in profile.documents where document.kind.isRequired {
            if document.status == .notSelected || document.status == .failed {
                errors["document-\(document.kind.rawValue)"] = "Выберите файл."
            }
        }
    }

    private func validateExamResults() {
        var subjects = Set<String>()
        for result in profile.examResults {
            let subject = result.subject.trimmingCharacters(in: .whitespacesAndNewlines)
            if subject.isEmpty {
                errors["exam-\(result.id)-subject"] = "Выберите предмет."
            } else if subjects.contains(subject) {
                errors["exam-\(result.id)-subject"] = "Этот предмет уже добавлен."
            }
            subjects.insert(subject)

            guard let score = Int(result.score),
                  (ExamRules.minimumScore...ExamRules.maximumScore).contains(score) else {
                errors["exam-\(result.id)-score"] = "Баллы: \(ExamRules.minimumScore)–\(ExamRules.maximumScore)."
                continue
            }
        }
    }

    private func validateAchievements() {
        for achievement in profile.achievements where achievement.isIncluded {
            if achievement.count < 1 {
                errors["achievement-\(achievement.category.rawValue)"] = "Количество должно быть не меньше 1."
            }
        }
    }

    private func validateAdditional() {
        require(profile.additional.citizenship, key: "citizenship", message: "Укажите гражданство.")
    }

    private func saveDraft(currentStep: Int) async -> Bool {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            try await repository.saveProfile(profile)
            if let accountRepository, let userID {
                try await accountRepository.updateProfileStatus(
                    id: userID,
                    status: .inProgress,
                    currentStep: currentStep
                )
            }
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            try await repository.saveProfile(profile)
            if let accountRepository, let userID {
                try await accountRepository.updateProfileStatus(
                    id: userID,
                    status: .complete,
                    currentStep: Self.totalSteps
                )
            }
            isComplete = true
            onProfileSaved?(profile)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func require(_ value: String, key: String, message: String) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors[key] = message
        }
    }

    private func clearAddressErrors() {
        errors["country"] = nil
        errors["region"] = nil
        errors["city"] = nil
    }
}
