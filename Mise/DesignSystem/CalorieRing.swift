import SwiftUI

/// The day's calories as a ring — serif numeral inside, saffron arc that
/// warms toward ember as you approach the goal, overshoot rendered as a
/// second lap in pure ember.
struct CalorieRing: View {
    let consumed: Double
    let goal: Double
    var diameter: CGFloat = 58

    private var fraction: Double { goal > 0 ? consumed / goal : 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.hairline, lineWidth: 3.5)

            // Goal tick at twelve o'clock — the finish line.
            Rectangle()
                .fill(Theme.creamFaint)
                .frame(width: 2, height: 6)
                .offset(y: -diameter / 2)

            Circle()
                .trim(from: 0, to: min(fraction, 1))
                .stroke(
                    AngularGradient(
                        colors: [Theme.saffron, Theme.saffron, Theme.ember],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if fraction > 1 {
                Circle()
                    .trim(from: 0, to: min(fraction - 1, 1))
                    .stroke(Theme.ember, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.ember.opacity(0.5), radius: 3)
            }

            VStack(spacing: -1) {
                Text("\(Int(consumed.rounded()))")
                    .font(Theme.statSmall(diameter * 0.26))
                    .foregroundStyle(Theme.cream)
                    .contentTransition(.numericText(value: consumed))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("KCAL")
                    .font(.system(size: diameter * 0.12, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(Theme.creamFaint)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: diameter, height: diameter)
        .animation(Motion.bounce, value: consumed)
    }
}

