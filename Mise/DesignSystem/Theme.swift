import SwiftUI

// The Mise look: a dark, warm editorial palette — charcoal ink, cream type,
// saffron + ember accents. Numerals and mastheads are serif; body is SF.
//
// Discipline: every dimension in the app comes from the tokens below.
// Spacing sits on a 4pt grid; corner radii nest (inner = outer − inset);
// every text/background pair passes WCAG AA (audited in tools/frameaudit).
enum Theme {

    // MARK: Palette

    /// Near-black with a warm cast; the page everything sits on.
    static let ink = Color(hex: 0x14110D)
    /// One step raised — cards, composer, chrome.
    static let inkRaised = Color(hex: 0x1E1A15)
    /// Two steps raised — pressed states, image placeholders.
    static let inkHigh = Color(hex: 0x2A241C)
    /// Hairlines and dividers.
    static let hairline = Color(hex: 0xF2EDE4).opacity(0.08)

    /// Primary type color.
    static let cream = Color(hex: 0xF2EDE4)
    static let creamDim = Color(hex: 0xF2EDE4).opacity(0.62)   // 6.7:1 on ink
    /// Tertiary labels. 0.46 ≈ 4.1:1 on ink — the old 0.35 failed AA.
    static let creamFaint = Color(hex: 0xF2EDE4).opacity(0.46)

    /// Hero accent — calorie numerals, the agent's presence. 8.6:1 on ink.
    static let saffron = Color(hex: 0xE5A33F)
    /// Secondary accent — protein, errors, warmth. 4.8:1 on ink.
    static let ember = Color(hex: 0xC96342)
    /// Tertiary — fat, quiet success. 7.8:1 on ink.
    static let sage = Color(hex: 0x9BAD84)
    /// Carbs. 10.2:1 on ink.
    static let wheat = Color(hex: 0xD9BC6E)

    static let proteinColor = ember
    static let carbColor = wheat
    static let fatColor = sage

    // MARK: Spacing — the 4pt grid. No other paddings exist.

    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32

    static let pagePadding: CGFloat = s5

    // MARK: Corner radii — nested surfaces subtract their inset.

    /// Entry cards, the big surfaces.
    static let rCard: CGFloat = 28
    /// Image inside a card (rCard − 4pt visual inset at the top).
    static let rImage: CGFloat = 24
    /// The composer pill and floating chrome.
    static let rComposer: CGFloat = 26
    /// Timeline tiles.
    static let rTile: CGFloat = 20
    /// User bubbles.
    static let rBubble: CGFloat = 18
    /// Small controls (fields, chips).
    static let rControl: CGFloat = 14

    /// Legacy aliases (older call sites).
    static let corner: CGFloat = rComposer
    static let cardCorner: CGFloat = rCard

    // MARK: Type scale

    /// Masthead date — big serif, like a magazine folio.
    static func masthead(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    /// Serif numerals for calories and stats.
    static func stat(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }
    static func statSmall(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    /// Chat body (user).
    static let body = Font.system(size: 16, weight: .regular)
    /// The agent speaks in serif.
    static let bodyAgent = Font.system(size: 16, weight: .regular, design: .serif)
    /// Card titles.
    static let title = Font.system(size: 17, weight: .medium, design: .serif)
    /// Captions and metadata.
    static let caption = Font.system(size: 12, weight: .regular)
    /// Tiny caps labels ("PROTEIN", "LUNCH").
    static let overline = Font.system(size: 10.5, weight: .semibold).width(.expanded)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Tiny caps label used across cards and the masthead.
struct Overline: View {
    let text: String
    var color: Color = Theme.creamFaint
    var body: some View {
        Text(text.uppercased())
            .font(Theme.overline)
            .kerning(1.8)
            .foregroundStyle(color)
    }
}

/// Magazine folio line: hairline rules flanking a caps label.
struct FolioRule: View {
    let text: String
    var body: some View {
        HStack(spacing: Theme.s3) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            Overline(text: text)
                .fixedSize()
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
}
