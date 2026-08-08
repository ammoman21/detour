import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var text: String
}

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case http(status: Int, message: String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key set. Open Settings to add your Anthropic API key."
        case .http(let status, let message):
            return "API error (\(status)): \(message)"
        case .malformedResponse:
            return "The API returned an unexpected response."
        }
    }
}

// Minimal streaming client for the Anthropic Messages API. No SDK dependency —
// one POST to /v1/messages with stream:true, parsed as server-sent events.
enum AnthropicClient {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let systemPrompt = """
    You are Detour, a tiny sidebar assistant for quick lookups while reading. \
    The user is midway through reading something and hit an unfamiliar term or concept. \
    Explain it clearly and briefly — a couple of short paragraphs at most, no preamble, \
    no bullet-point dumps unless asked. Assume a smart reader who wants the gist fast; \
    go deeper only when they ask follow-ups.
    """

    static func stream(
        messages: [ChatMessage],
        model: String,
        apiKey: String,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "system": systemPrompt,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.malformedResponse
        }

        guard http.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw AnthropicError.http(status: http.statusCode, message: extractErrorMessage(from: errorBody))
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let payload = Data(line.dropFirst(6).utf8)
            guard let event = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  let type = event["type"] as? String
            else { continue }

            switch type {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    onDelta(text)
                }
            case "error":
                let message = (event["error"] as? [String: Any])?["message"] as? String ?? "unknown stream error"
                throw AnthropicError.http(status: 0, message: message)
            case "message_stop":
                return
            default:
                break
            }
        }
    }

    private static func extractErrorMessage(from body: String) -> String {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String
        else {
            return body.isEmpty ? "no details" : String(body.prefix(300))
        }
        return message
    }
}
