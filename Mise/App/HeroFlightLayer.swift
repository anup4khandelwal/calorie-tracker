import SwiftUI

/// The shared element of the dive: when a plate is tapped in the catalog, it
/// lifts out of the grid and flies across the stage on the same spring as
/// the zoom, landing exactly where the entry card's photograph will be once
/// the thread settles — then fades through into the real card.
///
/// Pure custom choreography: no navigation transition, no matched geometry
/// across containers — one overlay view interpolating screen-space rects.
struct HeroFlightLayer: View {
    @Environment(AppModel.self) private var model
    let flight: HeroFlight

    @State private var landed = false
    @State private var faded = false

    var body: some View {
        GeometryReader { geo in
            let rect = landed ? targetRect(in: geo.size) : flight.from
            plate
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .opacity(faded ? 0 : 1)
                .shadow(color: .black.opacity(landed ? 0.35 : 0.5), radius: landed ? 24 : 14, y: landed ? 16 : 9)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task {
            // Fly on the zoom's own spring so plate and page move as one.
            withAnimation(Motion.zoom) { landed = true }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.22)) { faded = true }
            try? await Task.sleep(for: .milliseconds(260))
            model.heroFlight = nil
        }
    }

    /// Where the entry card's photograph sits after the thread lands scrolled
    /// to the entry (card centered): a square of pageWidth − padding − mat,
    /// its center a little above screen center to account for the card's
    /// caption block below the image.
    private func targetRect(in size: CGSize) -> CGRect {
        let side = size.width - 2 * Theme.pagePadding - 2 * Theme.s1
        return CGRect(
            x: (size.width - side) / 2,
            y: size.height / 2 - 61 - side / 2,
            width: side,
            height: side
        )
    }

    @ViewBuilder
    private var plate: some View {
        if let image = flight.image {
            if FoodImageEngine.isCutout(image) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.cream.opacity(0.10), lineWidth: 1))
            }
        } else {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0x39322A), Color(hex: 0x2B251E)],
                            center: .init(x: 0.42, y: 0.36),
                            startRadius: 4,
                            endRadius: 120
                        )
                    )
                Text(flight.emoji)
                    .font(.system(size: 42))
                    .opacity(0.9)
            }
        }
    }
}
