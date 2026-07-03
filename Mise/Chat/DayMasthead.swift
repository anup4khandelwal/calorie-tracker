import SwiftUI
import SwiftData

/// The magazine folio at the top of each day: overline, big serif date, and
/// the live calorie ring. Tapping it rises to the timeline.
struct DayMasthead: View {
    @Environment(AppModel.self) private var model
    let dayKey: String

    @Query private var entries: [FoodEntry]

    init(dayKey: String) {
        self.dayKey = dayKey
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day?.dayKey == dayKey })
    }

    private var consumed: Double { entries.reduce(0) { $0 + $1.calories } }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Overline(text: folioLine)
                Text(DayKey.mastheadTitle(for: dayKey))
                    .font(Theme.masthead(30))
                    .foregroundStyle(Theme.cream)
            }
            Spacer()

            CalorieRing(
                consumed: consumed,
                goal: model.store.profile().calorieGoal,
                diameter: 54
            )

            Button {
                model.showSettings = true
            } label: {
                Image(systemName: "circle.grid.2x1")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.creamDim)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.inkRaised))
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            model.setZoom(out: true)
        }
    }

    private var folioLine: String {
        guard let date = DayKey.date(for: dayKey) else { return "MISE" }
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return "MISE · \(f.string(from: date))"
    }
}
