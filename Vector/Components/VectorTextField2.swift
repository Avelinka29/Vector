import SwiftUI

struct VectorTextField2: View {
    let placeholder: String
    let icon: String?
    @Binding var text: String
    var errorMessage: String?
    var keyboardType: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(errorMessage == nil ? .systemGrey1 : .red, lineWidth: 1)
                    .frame(minHeight: 60)

                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .foregroundStyle(.systemBlue01)
                            .accessibilityHidden(true)
                    }

                    TextField("", text: $text)
                        .foregroundStyle(.systemDarkBlue)
                        .font(.body)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(capitalization)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 60)

                Text(placeholder)
                    .font(.caption)
                    .foregroundStyle(errorMessage == nil ? .systemDarkBlue.opacity(0.55) : .red)
                    .padding(.horizontal, 6)
                    .background(.systemWhite)
                    .padding(.leading, icon == nil ? 14 : 44)
                    .offset(y: -8)
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

#Preview {
    VectorTextField2(
        placeholder: "Фамилия",
        icon: "person",
        text: .constant("Иванов")
    )
    .padding()
}
