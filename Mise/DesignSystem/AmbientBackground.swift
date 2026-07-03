import SwiftUI

/// The page everything sits on — a shader-drawn near-black warm field with a
/// drifting candle glow, vignette, and paper grain. (Frame-audited: reads as
/// lit paper, never as a gradient poster.)
struct AmbientBackground: View {
    var body: some View {
        Rectangle()
            .fill(Theme.ink)
            .ambientField()
            .ignoresSafeArea()
    }
}

/// Chrome slab: real material blur, warm ink tint, then the procedural
/// glass pass (rim light, sheen, inner shadow, traveling gleam).
struct GlassChrome: ViewModifier {
    var corner: CGFloat = Theme.rComposer
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(Theme.inkRaised.opacity(0.72))
                    }
                    .glassRim(cornerRadius: corner)
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.30), radius: 16, y: 7)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            }
    }
}

extension View {
    func glassChrome(corner: CGFloat = Theme.rComposer) -> some View {
        modifier(GlassChrome(corner: corner))
    }
}

/// The one press behavior every tappable surface shares: a quick settle
/// inward with a whisper of dimming — never a color flash.
struct Pressable: ButtonStyle {
    var scale: CGFloat = 0.965
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
