import SwiftUI

/// The single stage everything plays on. The day pager (chat) and the
/// timeline (catalog) are both always present; `zoomProgress` crossfades,
/// scales and ripples between them so the transition feels like one surface
/// changing altitude rather than a navigation push.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showOnboarding = false

    var body: some View {
        let p = model.zoomProgress

        ZStack {
            AmbientBackground()

            // Timeline sits "behind" the thread, slightly oversized, and
            // settles into place as you pinch out.
            TimelineCatalogView()
                .scaleEffect(1.12 - 0.12 * p)
                .opacity(p * p) // lags the thread's exit, feels layered
                .blur(radius: (1 - p) * 10)
                .allowsHitTesting(model.zoomedOut)

            // The chat recedes: scales down toward the center, blurs, and
            // ripples like a liquid pane while in transit.
            DayPagerView()
                .scaleEffect(1 - 0.55 * p)
                .opacity(1 - p)
                .blur(radius: p * 6)
                .zoomRipple(progress: p)
                .allowsHitTesting(!model.zoomedOut)
        }
        .gesture(zoomPinch)
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

    /// Pinch in on the thread → rise to the timeline.
    /// Pinch out on the timeline → dive back into the current day.
    private var zoomPinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let magnification = value.magnification
                if model.zoomedOut {
                    // Diving back in: progress runs 1 → 0 as fingers spread.
                    let progress = 1 - (magnification - 1) * 1.6
                    model.dragZoom(progress: progress)
                } else {
                    // Rising out: progress runs 0 → 1 as fingers close.
                    let progress = (1 - magnification) * 2.2
                    model.dragZoom(progress: progress)
                }
            }
            .onEnded { _ in
                model.endDragZoom()
            }
    }
}
