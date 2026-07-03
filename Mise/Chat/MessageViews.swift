import SwiftUI

/// The user speaks in a quiet raised bubble, trailing-aligned.
struct UserBubbleView: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 48)
            Text(text)
                .font(Theme.body)
                .foregroundStyle(Theme.cream)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.inkHigh)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        }
                }
        }
    }
}

/// The agent speaks *on the page* — serif, no bubble — like marginalia in a
/// beautiful cookbook. Cards for anything it logged hang beneath the words.
struct AgentMessageView: View {
    @Environment(AppModel.self) private var model
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !message.text.isEmpty {
                Text(message.text)
                    .font(Theme.bodyAgent)
                    .foregroundStyle(Theme.cream)
                    .lineSpacing(3)
            }
            entryCards
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 32)
    }

    @ViewBuilder
    private var entryCards: some View {
        let entries = model.store.entries(ids: message.entryIDs)
        if !entries.isEmpty {
            VStack(spacing: 12) {
                ForEach(entries, id: \.id) { entry in
                    EntryCardView(entry: entry)
                }
            }
            .padding(.trailing, 16)
        }
    }
}

/// The in-flight agent turn: condensing text, live entry cards, activity line.
struct LiveTurnView: View {
    @Environment(AppModel.self) private var model
    let session: AgentSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !session.streamingText.isEmpty {
                StreamingTextView(text: session.streamingText)
            }

            let entries = model.store.entries(ids: session.turnEntryIDs)
            if !entries.isEmpty {
                VStack(spacing: 12) {
                    ForEach(entries, id: \.id) { entry in
                        EntryCardView(entry: entry)
                    }
                }
                .padding(.trailing, 16)
            }

            switch session.phase {
            case .waiting:
                AgentActivityView(label: "thinking…")
            case .tooling(let label):
                AgentActivityView(label: label)
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 32)
    }
}

/// Soft error surface — never a system alert.
struct ErrorBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13))
                .lineLimit(3)
        }
        .foregroundStyle(Theme.ember)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Capsule().fill(Theme.ember.opacity(0.12))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
