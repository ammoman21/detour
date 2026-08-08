import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    var openSettings: () -> Void

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            if viewModel.hasAPIKey {
                transcript
                Divider().opacity(0.4)
                inputBar
            } else {
                onboarding
            }
        }
        .onAppear { inputFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .detourPanelDidShow)) { _ in
            inputFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.secondary)
            Text("Detour")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Text(Preferences.model.shortName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: { viewModel.clear() }) {
                Image(systemName: "eraser")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear conversation (⌘K)")
            .keyboardShortcut("k", modifiers: .command)
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(12)
            }
            .onChange(of: viewModel.messages) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hit a term you don't know?")
                .font(.callout.weight(.medium))
            Text("Ask here, get the gist, press Esc, keep reading. This chat erases itself — nothing is saved.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    private var inputBar: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("What's LoRA? What does RLHF mean?…", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($inputFocused)
                .onSubmit { viewModel.send() }
            if viewModel.isStreaming {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(action: { viewModel.send() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.draft.isEmpty ? .secondary : .primary)
                .disabled(viewModel.draft.isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var onboarding: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "key.horizontal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("One-time setup")
                .font(.headline)
            Text("Detour talks directly to the Anthropic API with your own key. It's stored in your keychain and never leaves your Mac except to reach the API.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Add API Key…", action: openSettings)
                .keyboardShortcut(.defaultAction)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(rendered)
                .font(.callout)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    message.role == .user
                        ? AnyShapeStyle(Color.accentColor.opacity(0.28))
                        : AnyShapeStyle(.quaternary.opacity(0.6)),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var rendered: AttributedString {
        (try? AttributedString(
            markdown: message.text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(message.text)
    }
}

extension Notification.Name {
    static let detourPanelDidShow = Notification.Name("detourPanelDidShow")
}
