import SwiftUI

// The Mise look: a dark, warm editorial palette — charcoal ink, cream type,
// saffron + ember accents. Numerals and mastheads are serif; body is SF.
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
    static let creamDim = Color(hex: 0xF2EDE4).opacity(0.62)
    static let creamFaint = Color(hex: 0xF2EDE4).opacity(0.35)

    /// Hero accent — calorie numerals, the agent's presence.
    static let saffron = Color(hex: 0xE5A33F)
    /// Secondary accent — protein, warnings, warmth.
    static let ember = Color(hex: 0xC96342)
    /// Tertiary — fat, quiet success.
    static let sage = Color(hex: 0x9BAD84)
    /// Carbs.
    static let wheat = Color(hex: 0xD9BC6E)

    static let proteinColor = ember
    static let carbColor = wheat
    static let fatColor = sage

    // MARK: Type

    /// Masthead date — big serif, like a magazine folio.
    static func masthead(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    /// Serif numerals for calories and stats.
    static func stat(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }
    static func statSmall(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    /// Chat body.
    static let body = Font.system(size: 16, weight: .regular)
    static let bodyAgent = Font.system(size: 16, weight: .regular, design: .serif)
    /// Tiny caps labels ("PROTEIN", "LUNCH").
    static let overline = Font.system(size: 10.5, weight: .semibold).width(.expanded)

    // MARK: Metrics

    static let corner: CGFloat = 22
    static let cardCorner: CGFloat = 26
    static let pagePadding: CGFloat = 20
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
