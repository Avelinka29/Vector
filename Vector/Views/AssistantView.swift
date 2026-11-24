import Observation
import SwiftUI

nonisolated struct AssistantRequest: Encodable, Sendable {
    let message: String
    let history: [AssistantHistoryItem]
}

nonisolated struct AssistantHistoryItem: Encodable, Sendable {
    let role: String
    let content: String
}

nonisolated struct AssistantResponse: Decodable, Sendable {
    let answer: String
    let institutionIds: [String]
    let specialtyIds: [String]
    let isGenerated: Bool
    let relatedItems: [AssistantRelatedItem]
}

nonisolated struct AssistantRelatedItem: Decodable, Identifiable, Sendable {
    let id: String
    let kind: String
    let title: String
    let subtitle: String
    let sourceUrl: String
}

nonisolated struct AssistantStoredMessage: Decodable, Sendable {
    let id: UUID
    let role: String
    let content: String
    let institutionIds: [String]
    let specialtyIds: [String]
    let relatedItems: [AssistantRelatedItem]
}

nonisolated enum AssistantService {
    static func history() async throws -> [AssistantStoredMessage] {
        try await BackendAPIClient.shared.request(
            "/api/v1/assistant/history",
            authorized: true
        )
    }

    static func chat(
        message: String,
        history: [AssistantHistoryItem] = []
    ) async throws -> AssistantResponse {
        try await BackendAPIClient.shared.request(
            "/api/v1/assistant/chat",
            method: "POST",
            body: AssistantRequest(message: message, history: history),
            authorized: true,
            timeoutInterval: 25
        )
    }
}

nonisolated struct AssistantChatMessage: Identifiable, Sendable {
    enum Author: Sendable, Equatable {
        case user
        case assistant
    }

    let id: UUID
    let author: Author
    let text: String
    let institutionIds: [String]
    let specialtyIds: [String]
    let relatedItems: [AssistantRelatedItem]

    init(
        id: UUID = UUID(),
        author: Author,
        text: String,
        institutionIds: [String] = [],
        specialtyIds: [String] = [],
        relatedItems: [AssistantRelatedItem] = []
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.institutionIds = institutionIds
        self.specialtyIds = specialtyIds
        self.relatedItems = relatedItems
    }
}

@MainActor
@Observable
final class AssistantViewModel {
    var messages: [AssistantChatMessage] = [
        AssistantChatMessage(
            author: .assistant,
            text: "Привет! Я ИИ-помощник VECTOR. Помогу подобрать учреждение или специальность и объясню следующие шаги поступления. Важные сведения проверяйте по официальным источникам."
        )
    ]
    var draft = ""
    var isSending = false
    var isLoadingHistory = false
    var historyError: String?
    var errorMessage: String?
    private var didLoadHistory = false

    func loadHistory() async {
        guard !didLoadHistory, !isLoadingHistory, !isSending else { return }
        isLoadingHistory = true
        historyError = nil
        defer { isLoadingHistory = false }
        do {
            let stored = try await AssistantService.history()
            didLoadHistory = true
            guard !stored.isEmpty else { return }
            messages = stored.map {
                AssistantChatMessage(
                    id: $0.id,
                    author: $0.role == "user" ? .user : .assistant,
                    text: $0.content,
                    institutionIds: $0.institutionIds,
                    specialtyIds: $0.specialtyIds,
                    relatedItems: $0.relatedItems
                )
            }
        } catch {
            historyError = "Не удалось загрузить историю. Можно повторить загрузку или начать новый разговор."
        }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2, !isSending, !isLoadingHistory else { return }
        guard text.count <= 2000 else {
            errorMessage = "Сократите сообщение до 2000 символов."
            return
        }

        let history = messages.suffix(10).map { message in
            AssistantHistoryItem(
                role: message.author == .user ? "user" : "assistant",
                content: message.text
            )
        }

        draft = ""
        let outgoing = AssistantChatMessage(author: .user, text: text)
        messages.append(outgoing)
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let response = try await AssistantService.chat(
                message: text,
                history: history
            )
            messages.append(
                AssistantChatMessage(
                    author: .assistant,
                    text: response.answer,
                    institutionIds: response.institutionIds,
                    specialtyIds: response.specialtyIds,
                    relatedItems: response.relatedItems
                )
            )
        } catch {
            messages.removeAll { $0.id == outgoing.id }
            draft = text
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Не удалось получить ответ. Проверьте подключение и попробуйте ещё раз."
            )
        }
    }
}

struct AssistantView: View {
    private let suggestions = [
        "Подбери специальность",
        "Какие учреждения есть в Минске?",
        "Что делать для поступления?"
    ]

    let onClose: (() -> Void)?

    @State private var model = AssistantViewModel()
    @FocusState private var isComposerFocused: Bool

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            assistantHeader
            conversation
            composer
        }
        .background(
            LinearGradient(
                colors: [
                    Color.systemBlue01.opacity(0.035),
                    Color.systemWhite,
                    Color.systemWhite
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .task { await model.loadHistory() }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    isComposerFocused = false
                }
            }
        }
    }

    private var assistantHeader: some View {
        HStack(spacing: 12) {
            if let onClose {
                Button {
                    isComposerFocused = false
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.systemDarkBlue)
                        .frame(width: 36, height: 36)
                        .background(Color.systemGrey1.opacity(0.2), in: Circle())
                }
                .accessibilityLabel("Закрыть помощника")
            }

            ZStack {
                Circle()
                    .fill(Color.systemBlue01.opacity(0.12))
                Image(systemName: "sparkles")
                    .font(.title3.bold())
                    .foregroundStyle(.systemBlue01)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("AI-помощник")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.systemDarkBlue)
                Text("VECTOR · онлайн")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(model.messages) { message in
                        AssistantMessageBubble(message: message)
                            .id(message.id)
                    }

                    if model.messages.count == 1 {
                        suggestionList
                    }

                    if model.isSending {
                        AssistantTypingIndicator()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isComposerFocused = false
            }
            .onChange(of: model.messages.count) {
                guard let last = model.messages.last else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var suggestionList: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        model.draft = suggestion
                        Task { await send() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.systemBlue01)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.systemBlue01.opacity(0.08), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.systemBlue01.opacity(0.2))
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let historyError = model.historyError {
                HStack(alignment: .top) {
                    Text(historyError)
                    Button("Загрузить историю") {
                        Task { await model.loadHistory() }
                    }
                    .disabled(model.isLoadingHistory || model.isSending)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let errorMessage = model.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                    Spacer()
                    Button("Повторить") {
                        Task { await send() }
                    }
                    .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 4)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Сообщение помощнику…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isComposerFocused)
                    .font(.callout)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(Color.systemWhite, in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.systemGrey1.opacity(0.2))
                    }
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await send() }
                    }

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.systemBlue01, in: Circle())
                }
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
                .accessibilityLabel("Отправить сообщение")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        model.draft.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !model.isSending && !model.isLoadingHistory
    }

    private func send() async {
        guard canSend else { return }
        isComposerFocused = false
        await model.send()
    }
}

private struct AssistantMessageBubble: View {
    let message: AssistantChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.author == .user {
                Spacer(minLength: 40)
            } else {
                assistantAvatar
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey(message.text))
                    .font(.callout)
                    .lineSpacing(3)
                    .foregroundStyle(message.author == .user ? .white : Color.systemDarkBlue)
                    .textSelection(.enabled)

                if message.author == .assistant && !message.relatedItems.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(message.relatedItems) { item in
                            AssistantRecommendationCard(item: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: 310, alignment: .leading)
            .background {
                bubbleBackground
            }

            if message.author == .assistant {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var assistantAvatar: some View {
        Image(systemName: "sparkles")
            .font(.caption2.bold())
            .foregroundStyle(.systemBlue01)
            .frame(width: 26, height: 26)
            .background(Color.systemBlue01.opacity(0.1), in: Circle())
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.author == .user {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.systemBlue01, .systemBlue01.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.systemWhite)
                .shadow(color: Color.systemDarkBlue.opacity(0.07), radius: 10, y: 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.systemGrey1.opacity(0.14))
                }
        }
    }
}

private struct AssistantRecommendationCard: View {
    let item: AssistantRelatedItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind == "institution" ? "building.columns" : "book.closed")
                .foregroundStyle(.systemBlue01)
                .frame(width: 34, height: 34)
                .background(Color.systemBlue01.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.caption.weight(.semibold)).lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if let url = URL(string: item.sourceUrl), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                }
                .accessibilityLabel("Открыть источник")
            }
        }
        .padding(10)
        .background(Color.systemBlue01.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AssistantTypingIndicator: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.systemBlue01)
            Text("Ищу ответ и проверяю справочник…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .background(Color.systemGrey1.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
    }
}
