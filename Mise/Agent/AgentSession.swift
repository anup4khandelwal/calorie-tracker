import Foundation
import Observation

/// One live conversation with the agent — one per day thread.
/// Owns the streaming state the chat UI renders, runs the tool-use loop,
/// and persists finished turns back into SwiftData.
@MainActor
@Observable
final class AgentSession {

    enum Phase: Equatable {
        case idle
        /// Request sent, first token not yet arrived.
        case waiting
        case streaming
        /// Executing a tool; label is the human-readable activity line.
        case tooling(String)
    }

    let dayKey: String
    private let store: Store
    private let client = ClaudeClient()

    private(set) var phase: Phase = .idle
    /// Live text of the in-flight agent turn.
    private(set) var streamingText: String = ""
    /// Entries created so far during the in-flight turn (cards render live).
    private(set) var turnEntryIDs: [UUID] = []
    private(set) var lastError: String?

    /// Called whenever tools create entries (image generation hooks in here).
    var onEntriesLogged: (([UUID]) -> Void)?

    private var turnTask: Task<Void, Never>?

    init(dayKey: String, store: Store) {
        self.dayKey = dayKey
        self.store = store
    }

    var isBusy: Bool { phase != .idle }

    /// Drop a local greeting into an empty thread so the day never opens cold.
    func openIfNeeded() {
        guard let day = store.day(for: dayKey), day.messages.isEmpty else { return }
        let greeting = ChatMessage(role: .agent, text: SystemPrompt.greeting(store: store, dayKey: dayKey))
        greeting.day = day
        store.context.insert(greeting)
        store.save()
    }

    func cancel() {
        turnTask?.cancel()
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        lastError = nil

        guard let day = store.day(for: dayKey) else { return }
        let userMessage = ChatMessage(role: .user, text: trimmed)
        userMessage.day = day
        store.context.insert(userMessage)
        store.save()

        turnTask = Task { await runTurn() }
    }

    // MARK: - The turn loop

    private func runTurn() async {
        phase = .waiting
        streamingText = ""
        turnEntryIDs = []

        let system = SystemPrompt.build(store: store, dayKey: dayKey)
        let toolbox = AgentToolbox(store: store, dayKey: dayKey)
        var wire = historyWireMessages()

        defer { finishTurn() }

        for _ in 0..<6 { // hard cap on tool round-trips per user turn
            var textBuffer = ""
            var assistantBlocks: [[String: Any]] = []
            var pendingCalls: [ToolCall] = []
            var openTool: (id: String, name: String, json: String)?
            var stopReason: String?
            var needsBreak = !streamingText.isEmpty

            do {
                for try await event in client.stream(system: system, messages: wire, tools: AgentToolbox.schemas) {
                    if Task.isCancelled { return }
                    switch event {
                    case .textDelta(let delta):
                        if needsBreak {
                            streamingText += "\n\n"
                            needsBreak = false
                        }
                        if phase != .streaming { phase = .streaming }
                        textBuffer += delta
                        streamingText += delta

                    case .toolUseStart(let id, let name):
                        openTool = (id, name, "")
                        phase = .tooling(Self.activityLabel(for: name))

                    case .toolInputDelta(let partial):
                        openTool?.json += partial

                    case .contentBlockStop:
                        if let tool = openTool {
                            pendingCalls.append(ToolCall(id: tool.id, name: tool.name, inputJSON: tool.json))
                            openTool = nil
                        } else if !textBuffer.isEmpty {
                            assistantBlocks.append(["type": "text", "text": textBuffer])
                            textBuffer = ""
                        }

                    case .messageStop(let reason):
                        stopReason = reason
                    }
                }
            } catch {
                if !Task.isCancelled {
                    lastError = friendlyError(error)
                }
                return
            }

            guard stopReason == "tool_use", !pendingCalls.isEmpty else {
                return // end_turn (or refusal / max_tokens) — done
            }

            // Echo the assistant blocks (text + tool_use) exactly, then answer
            // every tool_use with a tool_result in a single user message.
            for call in pendingCalls {
                let inputObject: Any = {
                    guard let data = call.inputJSON.data(using: .utf8),
                          let parsed = try? JSONSerialization.jsonObject(with: data) else { return [String: Any]() }
                    return parsed
                }()
                assistantBlocks.append(["type": "tool_use", "id": call.id, "name": call.name, "input": inputObject])
            }
            wire.append(["role": "assistant", "content": assistantBlocks])

            var results: [[String: Any]] = []
            for call in pendingCalls {
                let outcome = toolbox.execute(call)
                if !outcome.createdEntryIDs.isEmpty {
                    turnEntryIDs.append(contentsOf: outcome.createdEntryIDs)
                    onEntriesLogged?(outcome.createdEntryIDs)
                    Haptics.shared.plated()
                }
                var block: [String: Any] = [
                    "type": "tool_result",
                    "tool_use_id": call.id,
                    "content": outcome.resultJSON,
                ]
                if outcome.isError { block["is_error"] = true }
                results.append(block)
            }
            wire.append(["role": "user", "content": results])
        }
    }

    private func finishTurn() {
        let text = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty || !turnEntryIDs.isEmpty {
            if let day = store.day(for: dayKey) {
                let message = ChatMessage(
                    role: .agent,
                    text: text.isEmpty ? "Logged." : text,
                    entryIDs: turnEntryIDs
                )
                message.day = day
                store.context.insert(message)
                store.save()
            }
            Haptics.shared.settle()
        }
        streamingText = ""
        turnEntryIDs = []
        phase = .idle
    }

    /// Persisted history → wire messages. Past turns are replayed as plain
    /// text (tool blocks are only needed within a live turn).
    private func historyWireMessages() -> [[String: Any]] {
        guard let day = store.day(for: dayKey, createIfMissing: false) else { return [] }
        var wire: [[String: Any]] = []
        // The API requires the first message to be role "user" — a fresh day
        // starts with our local greeting, so leading agent messages are folded
        // out (the greeting carries no information the model needs).
        var seenUser = false
        for message in day.sortedMessages {
            if message.role == .agent && !seenUser { continue }
            if message.role == .user { seenUser = true }
            let role = message.role == .user ? "user" : "assistant"
            var text = message.text
            if !message.entryIDs.isEmpty {
                let names = store.entries(ids: message.entryIDs).map(\.name).joined(separator: ", ")
                if !names.isEmpty { text += "\n[logged here: \(names)]" }
            }
            guard !text.isEmpty else { continue }
            wire.append(["role": role, "content": text])
        }
        return wire
    }

    private func friendlyError(_ error: Error) -> String {
        if let claude = error as? ClaudeError {
            return claude.errorDescription ?? "Something went sideways."
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "Can't reach the kitchen — check your connection."
        }
        return "Something went sideways: \(error.localizedDescription)"
    }

    private static func activityLabel(for tool: String) -> String {
        switch tool {
        case "search_food_db": "checking the pantry…"
        case "log_food": "plating it…"
        case "update_food_entry": "fixing the plate…"
        case "delete_food_entry": "clearing the plate…"
        case "get_day": "reading the day…"
        case "query_history": "flipping back a few pages…"
        case "set_profile": "making a note…"
        default: "working…"
        }
    }
}
