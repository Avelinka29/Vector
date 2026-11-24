import SwiftUI

struct InstitutionVisual: View {
    let imageURL: String?
    let type: String
    var isHero = false

    var body: some View {
        Group {
            if let url = validURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: isHero ? nil : 54, height: isHero ? 190 : 54)
        .frame(maxWidth: isHero ? .infinity : nil)
        .background(.systemBlue01.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: isHero ? 18 : 14))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Image("InstitutionPlaceholder")
            .resizable()
            .scaledToFill()
            .overlay(alignment: .bottomLeading) {
                if isHero {
                    Label(
                        type == "college" ? "Изображение колледжа" : "Изображение учреждения",
                        systemImage: type == "college" ? "building.2" : "building.columns"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(12)
                }
            }
    }

    private var validURL: URL? {
        guard let imageURL, let url = URL(string: imageURL),
              let scheme = url.scheme, ["https", "http"].contains(scheme) else { return nil }
        return url
    }
}

struct SpecialtyVisual: View {
    let specialty: SpecialtyRecord

    var body: some View {
        Group {
            if let url = validURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 54, height: 54)
        .background(.systemBlue01.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Image(systemName: symbolName)
            .font(.title2)
            .foregroundStyle(.systemBlue01)
    }

    private var symbolName: String {
        let value = specialty.name.lowercased()
        if value.contains("программ") || value.contains("информат") || value.contains("компьют") { return "laptopcomputer" }
        if value.contains("медицин") || value.contains("лечеб") || value.contains("фарма") { return "cross.case.fill" }
        if value.contains("педагог") || value.contains("образован") { return "person.2.fill" }
        if value.contains("эконом") || value.contains("финанс") || value.contains("бизнес") { return "chart.line.uptrend.xyaxis" }
        if value.contains("право") || value.contains("юрист") { return "building.columns.fill" }
        if value.contains("дизайн") || value.contains("искусств") { return "paintpalette.fill" }
        if value.contains("агро") || value.contains("лес") || value.contains("эколог") { return "leaf.fill" }
        if value.contains("инжен") || value.contains("технолог") || value.contains("механ") { return "gearshape.2.fill" }
        return "book.closed.fill"
    }

    private var validURL: URL? {
        guard let imageURL = specialty.imageURL, let url = URL(string: imageURL),
              let scheme = url.scheme, ["https", "http"].contains(scheme) else { return nil }
        return url
    }
}
