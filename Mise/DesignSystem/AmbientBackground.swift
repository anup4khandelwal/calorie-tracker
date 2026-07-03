import SwiftUI

/// The living page: a barely-moving warm mesh gradient under everything.
/// Motion is slow enough to read as candlelight, not animation.
struct AmbientBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let drift = Float(sin(t * 0.11)) * 0.06
            let drift2 = Float(cos(t * 0.07)) * 0.05

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5 + drift, 0.45 + drift2], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Theme.ink, Theme.ink, Color(hex: 0x181310),
                    Color(hex: 0x171310), Color(hex: 0x201812), Theme.ink,
                    Theme.ink, Color(hex: 0x191410), Theme.ink,
                ]
            )
        }
        .ignoresSafeArea()
    }
}

/// Standard chrome slab: raised ink, hairline, soft shadow, glass refraction.
struct GlassChrome: ViewModifier {
    var corner: CGFloat = Theme.corner
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Theme.inkRaised.opacity(0.92))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Theme.cream.opacity(0.16), Theme.cream.opacity(0.03)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                    .liquidGlass(strength: 5)
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            }
    }
}

extension View {
    func glassChrome(corner: CGFloat = Theme.corner) -> some View {
        modifier(GlassChrome(corner: corner))
    }
}
