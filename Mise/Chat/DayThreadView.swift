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
                ZStack(alignment: .top) {
                    scrollBody(session: session, proxy: proxy)

                    // Content slips under the masthead through a short fade,
                    // so scrolling reads as pages turning under the folio.
                    LinearGradient(
                        colors: [Theme.ink.opacity(0.9), Theme.ink.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: Theme.s5)
                    .allowsHitTesting(false)
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

    private func scrollBody(session: AgentSession, proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.s6 - 2) {
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
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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
            .animation(Motion.arrive, value: messages.count)
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.s2)
            .padding(.bottom, Theme.s3)
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
            landOnEntry(target, proxy: proxy)
        }
        .task {
            // A timeline dive can set the target *before* this thread
            // mounts — onChange never fires then, so check on arrival
            // (after the zoom has mostly settled).
            guard model.pendingScrollEntryID != nil else { return }
            try? await Task.sleep(for: .milliseconds(380))
            landOnEntry(model.pendingScrollEntryID, proxy: proxy)
        }
    }

    /// Scroll to (and clear) the entry the timeline asked us to land on.
    private func landOnEntry(_ target: UUID?, proxy: ScrollViewProxy) {
        guard let target, model.currentDayKey == dayKey else { return }
        if let message = messages.first(where: { $0.entryIDs.contains(target) }) {
            withAnimation(Motion.zoom) {
                proxy.scrollTo(message.id, anchor: .center)
            }
        }
        model.pendingScrollEntryID = nil
    }
}
