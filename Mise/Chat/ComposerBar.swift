import SwiftUI

/// Glass composer pinned to the bottom of a thread. Suggestion chips surface
/// on an empty day; the send jewel breathes while the agent is working.
struct ComposerBar: View {
    @Environment(AppModel.self) private var model
    let session: AgentSession
    let showSuggestions: Bool

    @State private var draft = ""
    @FocusState private var focused: Bool

    private let suggestions = [
        "Coffee with milk",
        "2 eggs and toast",
        "Big salad with chicken",
        "How am I doing this week?",
    ]

    var body: some View {
        VStack(spacing: 10) {
            if showSuggestions && draft.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { chip in
                            Button {
                                Haptics.shared.tick()
                                session.send(chip)
                            } label: {
                                Text(chip)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.creamDim)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background {
                                        Capsule().fill(Theme.inkRaised)
                                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.pagePadding)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 10) {
                TextField("Tell me what you ate…", text: $draft, axis: .vertical)
                    .font(Theme.body)
                    .foregroundStyle(Theme.cream)
                    .tint(Theme.saffron)
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit(send)

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSend ? Theme.ink : Theme.creamFaint)
                        .frame(width: 34, height: 34)
                        .background {
                            Circle().fill(canSend ? Theme.saffron : Theme.inkHigh)
                        }
                        .shadow(color: canSend ? Theme.saffron.opacity(0.45) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(Motion.snap, value: canSend)
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .glassChrome(corner: 26)
            .padding(.horizontal, Theme.pagePadding)
        }
        .padding(.bottom, 8)
        .animation(Motion.snap, value: draft.isEmpty)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !session.isBusy
    }

    private func send() {
        guard canSend else { return }
        Haptics.shared.tick()
        session.send(draft)
        draft = ""
    }
}
