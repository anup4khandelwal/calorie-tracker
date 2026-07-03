import SwiftUI
import SwiftData

/// The magazine folio at the top of each day: a ruled overline, the big
/// serif date with a live goal caption beneath, and the calorie ring.
/// Tapping the date block rises to the timeline.
struct DayMasthead: View {
    @Environment(AppModel.self) private var model
    let dayKey: String

    @Query private var entries: [FoodEntry]

    init(dayKey: String) {
        self.dayKey = dayKey
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day?.dayKey == dayKey })
    }

    private var consumed: Double { entries.reduce(0) { $0 + $1.calories } }
    private var protein: Double { entries.reduce(0) { $0 + $1.protein } }

    var body: some View {
        VStack(spacing: Theme.s3) {
            FolioRule(text: folioLine)

            HStack(alignment: .center, spacing: Theme.s4) {
                Button {
                    model.setZoom(out: true)
                } label: {
                    VStack(alignment: .leading, spacing: Theme.s1) {
                        Text(DayKey.mastheadTitle(for: dayKey))
                            .font(Theme.masthead(30))
                            .foregroundStyle(Theme.cream)
                        Text(goalCaption)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.creamFaint)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(Pressable(scale: 0.98))

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
                .buttonStyle(Pressable())
            }
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, Theme.s2)
        .padding(.bottom, Theme.s3)
    }

    private var goalCaption: String {
        let goal = Int(model.store.profile().calorieGoal)
        let proteinGoal = Int(model.store.profile().proteinGoal)
        if consumed <= 0 {
            return "goal \(goal) kcal · \(proteinGoal)g protein"
        }
        return "of \(goal) kcal · \(Int(protein.rounded())) of \(proteinGoal)g protein"
    }

    private var folioLine: String {
        guard let date = DayKey.date(for: dayKey) else { return "MISE" }
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return "MISE · \(f.string(from: date))"
    }
}
