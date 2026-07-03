import SwiftUI

/// A logged food, plated: the generated studio image on top (developing in
/// with film grain when it lands), then name, portion, and macros.
struct EntryCardView: View {
    @Environment(AppModel.self) private var model
    let entry: FoodEntry
    var compact = false

    /// 0 → 1 as the generated image develops in.
    @State private var revealProgress: Double = 0
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imagery
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Theme.cardCorner,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: 6,
                        topTrailingRadius: Theme.cardCorner
                    )
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Overline(text: entry.meal.label, color: Theme.saffron.opacity(0.85))
                        Text(entry.name)
                            .font(.system(size: 17, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.cream)
                            .lineLimit(2)
                        Text(entry.servingDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.creamFaint)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(Int(entry.calories.rounded()))")
                            .font(Theme.stat(24))
                            .foregroundStyle(Theme.cream)
                            .contentTransition(.numericText(value: entry.calories))
                        Text("KCAL")
                            .font(.system(size: 9, weight: .semibold))
                            .kerning(1.2)
                            .foregroundStyle(Theme.creamFaint)
                    }
                }
                if !compact {
                    HStack(spacing: 14) {
                        MacroPill(label: "P", grams: entry.protein, color: Theme.proteinColor)
                        MacroPill(label: "C", grams: entry.carbs, color: Theme.carbColor)
                        MacroPill(label: "F", grams: entry.fat, color: Theme.fatColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .fill(Theme.inkRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(Motion.arrive) { appeared = true }
            model.imageEngine.ensure(entry)
            if model.imageEngine.image(for: entry) != nil { revealProgress = 1 }
        }
        .contextMenu {
            Button(role: .destructive) {
                delete()
            } label: {
                Label("Remove from log", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var imagery: some View {
        let image = model.imageEngine.image(for: entry)
        ZStack {
            // Ceramic-plate placeholder: always underneath, so there is never
            // a hard pop — the photo develops in over it.
            placeholderPlate

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .grainReveal(progress: revealProgress)
                    .heatHaze()
                    .onAppear {
                        if revealProgress < 1 {
                            withAnimation(.easeInOut(duration: 1.4)) { revealProgress = 1 }
                        }
                    }
            }
        }
        .onChange(of: image == nil) { _, isNil in
            if !isNil {
                revealProgress = 0
                withAnimation(.easeInOut(duration: 1.4)) { revealProgress = 1 }
            }
        }
    }

    private var placeholderPlate: some View {
        ZStack {
            Rectangle().fill(Theme.inkHigh)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x3A332A), Color(hex: 0x2E2820)],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 4,
                        endRadius: 120
                    )
                )
                .padding(28)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            Text(entry.emoji)
                .font(.system(size: 44))
                .opacity(model.imageEngine.isGenerating(entry) ? 0.35 : 0.9)
        }
        .plateShimmer()
    }

    private func delete() {
        withAnimation(Motion.snap) {
            model.store.context.delete(entry)
            model.store.save()
        }
        Haptics.shared.tick()
    }
}
