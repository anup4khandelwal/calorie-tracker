import Foundation

// A minimal, dependency-free client for the Anthropic Messages API over SSE.
// Requests are built as JSON dictionaries so arbitrary tool blocks round-trip
// exactly; streaming events are decoded from the wire by their "type" field.

enum ClaudeError: LocalizedError {
    case missingKey
    case http(Int, String)
    case malformedStream(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            "No Anthropic API key yet — add one in Settings."
        case .http(let code, let body):
            "Claude API error \(code): \(body.prefix(300))"
        case .malformedStream(let detail):
            "Stream parsing failed: \(detail)"
        }
    }
}

/// Streaming events surfaced to the agent loop.
enum ClaudeStreamEvent {
    case textDelta(String)
    case toolUseStart(id: String, name: String)
    case toolInputDelta(String)
    case contentBlockStop
    /// Final stop reason for the message ("end_turn", "tool_use", "refusal", …).
    case messageStop(stopReason: String?)
}

struct ClaudeClient {
    static let model = "claude-opus-4-8"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Opens a streaming Messages request. `messages` and `tools` are wire-format
    /// JSON values (see AgentSession for construction).
    func stream(
        system: String,
        messages: [[String: Any]],
        tools: [[String: Any]]
    ) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let key = KeyVault.get(.anthropic) else { throw ClaudeError.missingKey }

                    var request = URLRequest(url: Self.endpoint)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(key, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let body: [String: Any] = [
                        "model": Self.model,
                        "max_tokens": 2048,
                        "stream": true,
                        "system": system,
                        "tools": tools,
                        "messages": messages,
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw ClaudeError.malformedStream("non-HTTP response")
                    }
                    guard http.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 2000 { break }
                        }
                        throw ClaudeError.http(http.statusCode, errorBody)
                    }

                    var stopReason: String?
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        // SSE frames: "event: name" lines then "data: {json}".
                        // Anthropic sends one JSON object per data line.
                        guard line.hasPrefix("data:") else { continue }
                        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        guard payload != "[DONE]", !payload.isEmpty,
                              let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String
                        else { continue }

                        switch type {
                        case "content_block_start":
                            if let block = json["content_block"] as? [String: Any],
                               (block["type"] as? String) == "tool_use",
                               let id = block["id"] as? String,
                               let name = block["name"] as? String {
                                continuation.yield(.toolUseStart(id: id, name: name))
                            }
                        case "content_block_delta":
                            if let delta = json["delta"] as? [String: Any] {
                                switch delta["type"] as? String {
                                case "text_delta":
                                    if let text = delta["text"] as? String {
                                        continuation.yield(.textDelta(text))
                                    }
                                case "input_json_delta":
                                    if let partial = delta["partial_json"] as? String {
                                        continuation.yield(.toolInputDelta(partial))
                                    }
                                default:
                                    break
                                }
                            }
                        case "content_block_stop":
                            continuation.yield(.contentBlockStop)
                        case "message_delta":
                            if let delta = json["delta"] as? [String: Any],
                               let reason = delta["stop_reason"] as? String {
                                stopReason = reason
                            }
                        case "message_stop":
                            continuation.yield(.messageStop(stopReason: stopReason))
                        case "error":
                            let message = (json["error"] as? [String: Any])?["message"] as? String
                            throw ClaudeError.http(529, message ?? "stream error")
                        default:
                            break // message_start, ping, …
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
