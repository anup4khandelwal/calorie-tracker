import SwiftUI
import SwiftData

/// One day's conversation: masthead, the message scroll, live turn, composer.
struct DayThreadView: View {
    @Environment(AppModel.self) private var model
    let dayKey: String

    @Query private var messages: [ChatMessage]

    init(dayKey: String) {
        self.dayKey = dayKey
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.day?.dayKey == dayKey },
            sort: \ChatMessage.createdAt
        )
    }

    var body: some View {
        let session = model.session(for: dayKey)

        VStack(spacing: 0) {
            DayMasthead(dayKey: dayKey)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(messages, id: \.id) { message in
                            Group {
                                switch message.role {
                                case .user:
                                    UserBubbleView(text: message.text)
                                case .agent:
                                    AgentMessageView(message: message)
                                }
                            }
                            .id(message.id)
                        }

                        if session.isBusy {
                            LiveTurnView(session: session)
                                .id("live-turn")
                        }

                        if let error = session.lastError {
                            ErrorBanner(text: error)
                        }

                        Color.clear.frame(height: 1).id("thread-bottom")
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.count) {
                    withAnimation(Motion.snap) {
                        proxy.scrollTo("thread-bottom", anchor: .bottom)
                    }
                }
                .onChange(of: session.streamingText) {
                    proxy.scrollTo("thread-bottom", anchor: .bottom)
                }
                .onChange(of: model.pendingScrollEntryID) { _, target in
                    guard target != nil, model.currentDayKey == dayKey else { return }
                    // Land on the message that carries the requested entry.
                    if let message = messages.first(where: { $0.entryIDs.contains(where: { $0 == target }) }) {
                        withAnimation(Motion.zoom) {
                            proxy.scrollTo(message.id, anchor: .center)
                        }
                    }
                    model.pendingScrollEntryID = nil
                }
            }

            ComposerBar(
                session: session,
                showSuggestions: messages.filter { $0.role == .user }.isEmpty
            )
        }
        .onAppear {
            session.openIfNeeded()
        }
    }
}
