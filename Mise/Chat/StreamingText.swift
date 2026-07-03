import SwiftUI

// Streaming text that *condenses* onto the page: each arriving glyph fades in
// with a small rise and a blur that resolves — instead of raw teletype.

extension Text.Layout {
    var flattenedRuns: some RandomAccessCollection<Text.Layout.Run> {
        flatMap { line in line }
    }
    var flattenedRunSlices: some RandomAccessCollection<Text.Layout.RunSlice> {
        flattenedRuns.flatMap { $0 }
    }
}

/// Reveal is measured in glyph-slices: slices with index < reveal are fully
/// set; the fractional frontier gets opacity/blur/rise interpolation.
struct GlyphRevealRenderer: TextRenderer, Animatable {
    var reveal: Double

    var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for (index, slice) in layout.flattenedRunSlices.enumerated() {
            let local = min(max(reveal - Double(index), 0), 1)
            guard local > 0 else { continue }
            var copy = context
            if local < 1 {
                copy.opacity = local
                copy.translateBy(x: 0, y: (1 - local) * 4)
                copy.addFilter(.blur(radius: (1 - local) * 3))
                // Fresh glyphs land warm — a saffron ember that cools to
                // cream as they settle (multiply toward the accent).
                let warmth = 1 - local
                copy.addFilter(.colorMultiply(Color(
                    red: 1 - 0.04 * warmth,
                    green: 1 - 0.28 * warmth,
                    blue: 1 - 0.62 * warmth
                )))
            }
            copy.draw(slice)
        }
    }
}

/// Live-streaming agent text. As `text` grows, the reveal frontier animates
/// forward so new glyphs condense in a soft wave.
struct StreamingTextView: View {
    let text: String
    @State private var reveal: Double = 0

    var body: some View {
        Text(text)
            .font(Theme.bodyAgent)
            .foregroundStyle(Theme.cream)
            .lineSpacing(3)
            .textRenderer(GlyphRevealRenderer(reveal: reveal))
            .onChange(of: text) { _, newValue in
                withAnimation(.easeOut(duration: 0.45)) {
                    reveal = Double(newValue.count)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) {
                    reveal = Double(text.count)
                }
            }
    }
}

/// The agent's presence while it works: a saffron ember that breathes, with
/// the current activity line ("plating it…") beside it.
struct AgentActivityView: View {
    let label: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = 0.72 + 0.28 * sin(t * 3.4)
            HStack(spacing: 10) {
                Circle()
                    .fill(Theme.saffron)
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulse)
                    .shadow(color: Theme.saffron.opacity(0.6 * pulse), radius: 6)
                Text(label)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.creamDim)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
