import SwiftUI

struct VectorPickerOption: Identifiable, Equatable {
    let id: String
    let title: String
}

struct VectorPicker: View {
    let title: String
    let icon: String?
    let options: [VectorPickerOption]
    @Binding var selection: String
    var isDisabled = false
    var errorMessage: String?

    private var selectedTitle: String {
        options.first { $0.id == selection }?.title ?? title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Menu {
                ForEach(options) { option in
                    Button(option.title) {
                        selection = option.id
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    if let icon {
                        Image(systemName: icon)
                            .foregroundStyle(.systemBlue01)
                    }
                    Text(selectedTitle)
                        .foregroundStyle(selection.isEmpty ? .systemDarkBlue.opacity(0.45) : .systemDarkBlue)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.systemDarkBlue.opacity(0.45))
                }
                .font(.body)
                .padding(.horizontal, 18)
                .frame(minHeight: 60)
                .background(.systemWhite)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(errorMessage == nil ? .systemGrey1 : .red, lineWidth: 1)
                }
            }
            .disabled(isDisabled)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 8)
            }
        }
        .opacity(isDisabled ? 0.55 : 1)
    }
}

#Preview {
    VectorPicker(
        title: "Выберите",
        icon: "location",
        options: [VectorPickerOption(id: "1", title: "Вариант")],
        selection: .constant("")
    )
}
