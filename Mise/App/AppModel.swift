import SwiftUI
import SwiftData
import Observation

/// App-wide state: the model container, per-day agent sessions, the image
/// engine, and the thread ↔ timeline zoom choreography.
@MainActor
@Observable
final class AppModel {

    let container: ModelContainer
    let store: Store
    let imageEngine: FoodImageEngine

    // MARK: Navigation state

    /// Which day thread the pager is on.
    var currentDayKey: String = DayKey.today
    /// 0 = fully in the thread, 1 = fully in the timeline.
    var zoomProgress: Double = 0
    /// Committed zoom state (progress animates toward this).
    var zoomedOut = false
    /// Entry the timeline wants the thread to scroll to after diving in.
    var pendingScrollEntryID: UUID?

    var showSettings = false

    /// Session cache — ignored by observation so lazily creating a session
    /// inside a view body doesn't invalidate that same body.
    @ObservationIgnored private var sessions: [String: AgentSession] = [:]

    init() {
        do {
            container = try ModelContainer(
                for: DayLog.self, ChatMessage.self, FoodEntry.self, UserProfile.self
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        let store = Store(context: container.mainContext)
        self.store = store
        self.imageEngine = FoodImageEngine(store: store)
        // Materialize the profile row now so view bodies never insert it.
        _ = store.profile()
        store.save()
    }

    // MARK: Sessions

    func session(for dayKey: String) -> AgentSession {
        if let existing = sessions[dayKey] { return existing }
        let session = AgentSession(dayKey: dayKey, store: store)
        session.onEntriesLogged = { [weak self] ids in
            guard let self else { return }
            for entry in self.store.entries(ids: ids) {
                self.imageEngine.ensure(entry)
            }
        }
        sessions[dayKey] = session
        return session
    }

    /// The strip of days the pager can reach: the last 60 days through today.
    var pagerDayKeys: [String] {
        stride(from: -59, through: 0, by: 1).map { DayKey.key(daysFromToday: $0) }
    }

    var needsOnboarding: Bool {
        !store.profile().onboarded || !KeyVault.hasAnthropicKey
    }

    // MARK: Zoom choreography

    func setZoom(out: Bool) {
        guard zoomedOut != out || zoomProgress != (out ? 1 : 0) else { return }
        zoomedOut = out
        Haptics.shared.thud()
        withAnimation(Motion.zoom) {
            zoomProgress = out ? 1 : 0
        }
    }

    /// Live pinch update from the thread (progress toward the timeline).
    func dragZoom(progress: Double) {
        zoomProgress = min(max(progress, 0), 1)
    }

    /// Gesture ended — commit past the threshold, otherwise spring back.
    /// The threshold is asymmetric so the current state has a little stickiness.
    func endDragZoom() {
        let out = zoomProgress > (zoomedOut ? 0.68 : 0.32)
        if out != zoomedOut { Haptics.shared.thud() }
        zoomedOut = out
        withAnimation(Motion.zoom) { zoomProgress = out ? 1 : 0 }
    }

    /// Timeline → dive into a day (optionally landing on an entry).
    func open(dayKey: String, entryID: UUID? = nil) {
        currentDayKey = dayKey
        pendingScrollEntryID = entryID
        setZoom(out: false)
    }
}
