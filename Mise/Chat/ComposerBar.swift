import SwiftUI

/// Glass composer pinned to the bottom of a thread. Suggestion chips surface
/// on an empty day as serif prompts; the send jewel warms when there's
/// something to send.
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
        VStack(spacing: Theme.s3) {
            if showSuggestions && draft.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.s2) {
                        ForEach(suggestions, id: \.self) { chip in
                            Button {
                                Haptics.shared.tick()
                                session.send(chip)
                            } label: {
                                Text(chip)
                                    .font(.system(size: 13.5, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundStyle(Theme.creamDim)
                                    .padding(.horizontal, Theme.s3 + 2)
                                    .padding(.vertical, Theme.s2)
                                    .background {
                                        Capsule().fill(Theme.inkRaised)
                                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                                    }
                            }
                            .buttonStyle(Pressable())
                        }
                    }
                    .padding(.horizontal, Theme.pagePadding)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: Theme.s3) {
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
                        .shadow(color: canSend ? Theme.saffron.opacity(0.4) : .clear, radius: 8)
                }
                .buttonStyle(Pressable(scale: 0.9))
                .disabled(!canSend)
                .animation(Motion.snap, value: canSend)
            }
            .padding(.leading, Theme.s4 + 2)
            .padding(.trailing, Theme.s2)
            .padding(.vertical, Theme.s2)
            .glassChrome(corner: Theme.rComposer)
            .padding(.horizontal, Theme.pagePadding)
        }
        .padding(.bottom, Theme.s2)
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
