import Observation
import SwiftUI

nonisolated private struct AssistantRequest: Encodable, Sendable {
    let message: String
}

nonisolated private struct AssistantResponse: Decodable, Sendable {
    let answer: String
    let institutionIds: [String]
    let specialtyIds: [String]
    let isGenerated: Bool
}

nonisolated struct AssistantChatMessage: Identifiable, Sendable {
    enum Author: Sendable, Equatable {
        case user
        case assistant
    }

    let id = UUID()
    let author: Author
    let text: String
}

@MainActor
@Observable
final class AssistantViewModel {
    var messages: [AssistantChatMessage] = [
        AssistantChatMessage(
            author: .assistant,
            text: "Привет! Я помогу найти учреждение или специальность в справочнике VECTOR. Напишите город, название или направление обучения."
        )
    ]
    var draft = ""
    var isSending = false
    var errorMessage: String?

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2, !isSending else { return }

        draft = ""
        messages.append(AssistantChatMessage(author: .user, text: text))
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let response: AssistantResponse = try await BackendAPIClient.shared.request(
                "/api/v1/assistant/chat",
                method: "POST",
                body: AssistantRequest(message: text),
                authorized: true
            )
            messages.append(AssistantChatMessage(author: .assistant, text: response.answer))
        } catch {
            errorMessage = UserFacingError.message(
                for: error,
                fallback: "Помощник временно недоступен. Попробуйте ещё раз."
            )
        }
    }
}

struct AssistantView: View {
    @State private var model = AssistantViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.messages) { message in
                            HStack {
                                if message.author == .user {
                                    Spacer(minLength: 44)
                                }

                                Text(message.text)
                                    .font(.body)
                                    .foregroundStyle(message.author == .user ? .white : Color.systemDarkBlue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        message.author == .user
                                            ? Color.systemBlue01
                                            : Color.systemDarkBlue.opacity(0.055),
                                        in: RoundedRectangle(cornerRadius: 18)
                                    )

                                if message.author == .assistant {
                                    Spacer(minLength: 44)
                                }
                            }
                            .id(message.id)
                        }

                        if model.isSending {
                            HStack {
                                ProgressView()
                                Text("Ищу в справочнике…")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                }
                .onChange(of: model.messages.count) {
                    guard let last = model.messages.last else { return }
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                TextField("Спросите о поступлении…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await model.send() }
                    }

                Button {
                    Task { await model.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                }
                .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || model.isSending)
            }
            .padding(16)
            .background(.bar)
        }
        .background(.systemWhite)
        .navigationTitle("AI-помощник")
        .navigationBarTitleDisplayMode(.inline)
    }
}
