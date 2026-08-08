import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isStreaming = false
    @Published var errorMessage: String?
    @Published var hasAPIKey = Keychain.apiKey != nil

    private var streamTask: Task<Void, Never>?
    private var eraseTimer: Timer?

    // Keep the request payload small — this is a scratch conversation, not a
    // long-lived chat. Oldest turns fall off past this limit.
    private let maxTurns = 24

    func refreshAPIKeyState() {
        hasAPIKey = Keychain.apiKey != nil
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        guard let apiKey = Keychain.apiKey else {
            hasAPIKey = false
            return
        }

        draft = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, text: text))
        if messages.count > maxTurns {
            messages.removeFirst(messages.count - maxTurns)
        }

        let history = messages
        let model = Preferences.model.rawValue
        messages.append(ChatMessage(role: .assistant, text: ""))
        isStreaming = true

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await AnthropicClient.stream(messages: history, model: model, apiKey: apiKey) { [weak self] delta in
                    Task { @MainActor in self?.appendDelta(delta) }
                }
            } catch is CancellationError {
                // user cleared the chat mid-stream; nothing to report
            } catch {
                self.handleStreamFailure(error)
            }
            self.isStreaming = false
        }
    }

    private func handleStreamFailure(_ error: Error) {
        // drop the empty assistant bubble the failed stream left behind
        if let last = messages.last, last.role == .assistant, last.text.isEmpty {
            messages.removeLast()
        }
        errorMessage = error.localizedDescription
    }

    private func appendDelta(_ delta: String) {
        guard var last = messages.last, last.role == .assistant else { return }
        last.text += delta
        messages[messages.count - 1] = last
    }

    func clear() {
        streamTask?.cancel()
        streamTask = nil
        messages = []
        draft = ""
        errorMessage = nil
        isStreaming = false
    }

    // Ephemerality: the transcript survives an accidental dismissal (clicking
    // back into your reading), but erases itself two minutes after the panel
    // hides. Nothing is ever written to disk.
    func panelDidHide() {
        eraseTimer?.invalidate()
        eraseTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.clear() }
        }
    }

    func panelDidShow() {
        eraseTimer?.invalidate()
        eraseTimer = nil
        refreshAPIKeyState()
    }
}
