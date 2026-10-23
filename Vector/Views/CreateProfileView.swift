import SwiftUI

struct CreateProfileView: View {
    @State private var model: RegistrationViewModel
    @State private var showMain = false
    let onContinue: (() -> Void)?

    init(
        model: RegistrationViewModel? = nil,
        onContinue: (() -> Void)? = nil
    ) {
        _model = State(initialValue: model ?? RegistrationViewModel())
        self.onContinue = onContinue
    }

    var body: some View {
        Group {
            if model.isComplete {
                ProfileCreatedView {
                    if let onContinue {
                        onContinue()
                    } else {
                        showMain = true
                    }
                }
            } else {
                RegistrationWizardView(model: model)
            }
        }
        .background(.systemWhite)
        .navigationBarBackButtonHidden(model.currentStep > 1)
        .navigationDestination(isPresented: $showMain) {
            MainTabView(profile: model.profile)
                .navigationBarBackButtonHidden(true)
        }
    }
}

struct RegistrationWizardView: View {
    @Bindable var model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 0) {
            RegistrationHeader(
                step: model.currentStep,
                totalSteps: RegistrationViewModel.totalSteps,
                title: model.title,
                subtitle: model.subtitle
            )

            ScrollView {
                RegistrationStepContent(model: model)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)

            RegistrationNavigationBar(model: model)
        }
        .background(.systemWhite)
    }
}

struct RegistrationHeader: View {
    let step: Int
    let totalSteps: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Шаг \(step) из \(totalSteps)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.systemDarkBlue.opacity(0.55))

            HStack(spacing: 6) {
                ForEach(1...totalSteps, id: \.self) { item in
                    Capsule()
                        .fill(item <= step ? .systemBlue01 : .systemGrey1.opacity(0.25))
                        .frame(height: 5)
                }
            }

            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.systemDarkBlue)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.systemDarkBlue.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background(.systemWhite)
    }
}

struct RegistrationStepContent: View {
    let model: RegistrationViewModel

    var body: some View {
        VStack {
            switch model.currentStep {
            case 1: PersonalStepView(model: model)
            case 2: ContactStepView(model: model)
            case 3: PassportStepView(model: model)
            case 4: AddressStepView(model: model)
            case 5: EducationStepView(model: model)
            case 6: InstitutionStepView(model: model)
            case 7: DocumentsStepView(model: model)
            case 8: ExamResultsStepView(model: model)
            case 9: AchievementsStepView(model: model)
            case 10: AdditionalStepView(model: model)
            default: EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.currentStep)
    }
}

struct RegistrationNavigationBar: View {
    let model: RegistrationViewModel

    var body: some View {
        VStack(spacing: 10) {
            if let saveError = model.saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    await model.advance()
                }
            } label: {
                HStack(spacing: 10) {
                    if model.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(model.currentStep == RegistrationViewModel.totalSteps ? "Создать профиль" : "Далее")
                        if model.currentStep < RegistrationViewModel.totalSteps {
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(model.isSaving)
            .opacity(model.isSaving ? 0.7 : 1)

            if model.currentStep > 1 {
                Button("Назад") {
                    model.goBack()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.systemBlue01)
                .frame(maxWidth: .infinity, minHeight: 38)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.systemWhite.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -3)))
        .sensoryFeedback(.selection, trigger: model.currentStep)
    }
}

struct ProfileCreatedView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAppear = false
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 132, height: 132)
                .background(.systemBlue01, in: Circle())
                .shadow(color: .systemBlue01.opacity(0.25), radius: 20, y: 10)
                .scaleEffect(didAppear ? 1 : 0.55)
                .opacity(didAppear ? 1 : 0)

            VStack(spacing: 10) {
                Text("Профиль создан!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.systemDarkBlue)
                Text("Анкета сохранена в вашем аккаунте. Фотографии документов остаются только на этом устройстве.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Перейти в приложение", action: onContinue)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(.systemBlue01, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(24)
        .background(.systemWhite)
        .sensoryFeedback(.success, trigger: didAppear)
        .onAppear {
            if reduceMotion {
                didAppear = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                    didAppear = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreateProfileView()
    }
}
