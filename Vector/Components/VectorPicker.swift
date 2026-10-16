import SwiftUI

struct VectorPickerOption: Identifiable, Hashable {
    let id: String
    let title: String
}

struct VectorPicker: View {
    let title: String
    let icon: String
    let options: [VectorPickerOption]
    @Binding var selection: String
    let errorMessage: String?

    init(
        title: String,
        icon: String,
        options: [VectorPickerOption],
        selection: Binding<String>,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.icon = icon
        self.options = options
        self._selection = selection
        self.errorMessage = errorMessage
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
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .foregroundStyle(.systemBlue01)

                    Text(selectedTitle ?? title)
                        .foregroundStyle(selectedTitle == nil ? .secondary : .systemDarkBlue)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(.systemWhite, in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(errorMessage == nil ? .systemGrey1 : .red, lineWidth: 1)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 8)
            }
        }
    }

    private var selectedTitle: String? {
        options.first { $0.id == selection }?.title
    }
}
