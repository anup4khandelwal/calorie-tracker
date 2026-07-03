import SwiftUI

/// A logged food, plated. The photograph sits *matted* — inset 4pt inside the
/// card like a mounted print — and develops in with the film shader. Below:
/// meal + time folio, baseline-aligned name and calorie numeral, portion,
/// and three macro meters showing where the calories actually come from.
struct EntryCardView: View {
    @Environment(AppModel.self) private var model
    let entry: FoodEntry
    var compact = false

    /// 0 → 1 as the photograph develops.
    @State private var developProgress: Double = 0
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imagery
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rImage, style: .continuous))
                .padding(Theme.s1) // the mat

            VStack(alignment: .leading, spacing: Theme.s2) {
                HStack {
                    Overline(text: entry.meal.label, color: Theme.saffron.opacity(0.9))
                    Spacer()
                    Overline(text: timeLabel)
                }

                HStack(alignment: .lastTextBaseline, spacing: Theme.s3) {
                    Text(entry.name)
                        .font(Theme.title)
                        .foregroundStyle(Theme.cream)
                        .lineLimit(2)
                    Spacer(minLength: Theme.s2)
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(Int(entry.calories.rounded()))")
                            .font(Theme.stat(26))
                            .foregroundStyle(Theme.cream)
                            .contentTransition(.numericText(value: entry.calories))
                        Text("KCAL")
                            .font(Theme.overline)
                            .kerning(1.2)
                            .foregroundStyle(Theme.creamFaint)
                    }
                    .layoutPriority(1)
                }

                Text(entry.servingDescription)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.creamFaint)

                if !compact {
                    HStack(spacing: Theme.s3) {
                        MacroMeter(label: "PROTEIN", grams: entry.protein, color: Theme.proteinColor, fraction: share(entry.protein * 4))
                        MacroMeter(label: "CARBS", grams: entry.carbs, color: Theme.carbColor, fraction: share(entry.carbs * 4))
                        MacroMeter(label: "FAT", grams: entry.fat, color: Theme.fatColor, fraction: share(entry.fat * 9))
                    }
                    .padding(.top, Theme.s1)
                }
            }
            .padding(.horizontal, Theme.s4)
            .padding(.top, Theme.s3)
            .padding(.bottom, Theme.s4)
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous)
                .fill(Theme.inkRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Theme.cream.opacity(0.13), Theme.cream.opacity(0.03)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(Motion.arrive) { appeared = true }
            model.imageEngine.ensure(entry)
            if model.imageEngine.image(for: entry) != nil { developProgress = 1 }
        }
        .contextMenu {
            Button(role: .destructive) {
                delete()
            } label: {
                Label("Remove from log", systemImage: "trash")
            }
        }
    }

    /// This macro's share of the entry's calories, for the meter fill.
    private func share(_ kcal: Double) -> Double {
        guard entry.calories > 1 else { return 0 }
        return min(max(kcal / entry.calories, 0), 1)
    }

    private var timeLabel: String {
        entry.createdAt.formatted(date: .omitted, time: .shortened)
    }

    @ViewBuilder
    private var imagery: some View {
        let image = model.imageEngine.image(for: entry)
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .filmDevelop(progress: developProgress)
                    .onAppear {
                        if developProgress < 1 {
                            withAnimation(.easeInOut(duration: 1.6)) { developProgress = 1 }
                        }
                    }
            } else {
                placeholderPlate
            }
        }
        .onChange(of: image == nil) { wasNil, isNil in
            if wasNil && !isNil {
                developProgress = 0
                withAnimation(.easeInOut(duration: 1.6)) { developProgress = 1 }
            }
        }
    }

    /// The dim studio before the shot arrives — breathing key light while
    /// generating, quiet and static otherwise.
    private var placeholderPlate: some View {
        ZStack {
            Rectangle().fill(Theme.inkHigh)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x3A332A), Color(hex: 0x2E2820)],
                        center: .init(x: 0.42, y: 0.36),
                        startRadius: 4,
                        endRadius: 130
                    )
                )
                .padding(Theme.s6 + Theme.s1)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            Text(entry.emoji)
                .font(.system(size: 46))
                .opacity(model.imageEngine.isGenerating(entry) ? 0.35 : 0.9)
        }
        .modifier(BreathingWhileGenerating(active: model.imageEngine.isGenerating(entry)))
    }

    private func delete() {
        withAnimation(Motion.snap) {
            model.store.context.delete(entry)
            model.store.save()
        }
        Haptics.shared.tick()
    }
}

/// Applies the still-life shader only while a photo is actually generating,
/// so idle placeholders cost nothing.
private struct BreathingWhileGenerating: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            content.stillLife()
        } else {
            content
        }
    }
}

/// One macro's meter: caps label, serif grams, and a 3pt bar showing this
/// macro's share of the entry's calories.
struct MacroMeter: View {
    let label: String
    let grams: Double
    let color: Color
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.s1) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(Theme.creamFaint)
                Spacer(minLength: 0)
                Text("\(Int(grams.rounded()))g")
                    .font(Theme.statSmall(12))
                    .foregroundStyle(Theme.creamDim)
                    .contentTransition(.numericText(value: grams))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule()
                        .fill(color.opacity(0.9))
                        .frame(width: max(proxy.size.width * fraction, 3))
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
    }
}
