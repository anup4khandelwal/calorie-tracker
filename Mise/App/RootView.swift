import SwiftUI

/// The single stage everything plays on.
///
/// The zoom is a *floating page*: pinch in and the whole thread lifts off —
/// corners round, a shadow grows, it recedes crisply (never blurred) while
/// the timeline settles into place beneath it with a touch of parallax.
/// Every layer runs its own easing off one raw progress, so the gesture is
/// fully interactive and interruptible at any frame.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showOnboarding = false

    var body: some View {
        let p = model.zoomProgress
        let lift = Motion.easeOutCubic(p)          // the page's departure
        let settle = Motion.easeInOut(p)           // the timeline's arrival

        ZStack {
            AmbientBackground()

            // The record, settling in beneath the departing page.
            TimelineCatalogView()
                .scaleEffect(1.045 - 0.045 * settle)
                .offset(y: 12 * (1 - settle))
                .opacity(Motion.window(p, 0.10, 0.65))
                .allowsHitTesting(model.zoomedOut)

            // The day thread as a physical page.
            ZStack {
                AmbientBackground()
                DayPagerView()
            }
            .clipShape(RoundedRectangle(cornerRadius: 44 * lift, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 44 * lift, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
                    .opacity(Motion.window(p, 0.02, 0.2))
            }
            .background {
                // Layered shadow: one deep ambient, one tight contact.
                RoundedRectangle(cornerRadius: 44 * lift, style: .continuous)
                    .fill(.black)
                    .shadow(color: .black.opacity(0.45 * lift), radius: 34 * lift, y: 20 * lift)
                    .shadow(color: .black.opacity(0.30 * lift), radius: 6 * lift, y: 3 * lift)
                    .opacity(lift > 0.001 ? 1 : 0)
            }
            .scaleEffect(1 - 0.16 * lift)
            .brightness(-0.05 * lift)
            .zoomRipple(progress: p)
            .opacity(1 - Motion.window(p, 0.72, 1.0))
            .allowsHitTesting(!model.zoomedOut)
        }
        .simultaneousGesture(zoomPinch) // must coexist with scrolls + pager swipes
        .sheet(isPresented: Binding(
            get: { model.showSettings },
            set: { model.showSettings = $0 }
        )) {
            SettingsView()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .onAppear {
            showOnboarding = model.needsOnboarding
        }
    }

    /// Pinch in on the thread → the page lifts away to the timeline.
    /// Pinch out on the timeline → dive back into the current day.
    private var zoomPinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let magnification = value.magnification
                if model.zoomedOut {
                    let progress = 1 - (magnification - 1) * 1.6
                    model.dragZoom(progress: progress)
                } else {
                    let progress = (1 - magnification) * 2.2
                    model.dragZoom(progress: progress)
                }
            }
            .onEnded { _ in
                model.endDragZoom()
            }
    }
}
