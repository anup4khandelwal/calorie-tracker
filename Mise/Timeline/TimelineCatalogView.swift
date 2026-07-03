import SwiftUI
import SwiftData

/// The zoomed-out record: every meal ever logged, as one continuous magazine
/// catalog. Days become spreads; meals become plates on the page.
struct TimelineCatalogView: View {
    @Environment(AppModel.self) private var model

    @Query(sort: \FoodEntry.createdAt, order: .reverse)
    private var allEntries: [FoodEntry]

    private var sections: [(dayKey: String, entries: [FoodEntry])] {
        let grouped = Dictionary(grouping: allEntries) { $0.day?.dayKey ?? "?" }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.0 > $1.0 }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30, pinnedViews: []) {
                header

                if sections.isEmpty {
                    emptyState
                } else {
                    ForEach(sections, id: \.dayKey) { section in
                        daySection(section.dayKey, entries: section.entries)
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 60)
        }
        .safeAreaInset(edge: .bottom) {
            returnButton
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Overline(text: "MISE · THE RECORD")
            Text("Everything\nyou've plated")
                .font(Theme.masthead(40))
                .foregroundStyle(Theme.cream)
                .lineSpacing(-2)
        }
        .padding(.top, 24)
        .padding(.bottom, 6)
    }

    private func daySection(_ dayKey: String, entries: [FoodEntry]) -> some View {
        let total = entries.reduce(0.0) { $0 + $1.calories }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(DayKey.shortTitle(for: dayKey))
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text("\(Int(total.rounded()))")
                    .font(Theme.stat(19))
                    .foregroundStyle(Theme.saffron)
                Text("KCAL")
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Theme.creamFaint)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                model.open(dayKey: dayKey)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(entries, id: \.id) { entry in
                    MealCard(entry: entry)
                        .onTapGesture {
                            Haptics.shared.tick()
                            model.open(dayKey: dayKey, entryID: entry.id)
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing plated yet.")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(Theme.creamDim)
            Text("Dive back into today and tell me what you ate — every dish gets its own portrait here.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.creamFaint)
                .frame(maxWidth: 300, alignment: .leading)
        }
        .padding(.top, 40)
    }

    private var returnButton: some View {
        Button {
            model.setZoom(out: false)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, weight: .semibold))
                Text(DayKey.mastheadTitle(for: model.currentDayKey))
                    .font(.system(size: 14, weight: .semibold, design: .serif))
            }
            .foregroundStyle(Theme.cream)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassChrome(corner: 24)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
    }
}

/// One plate in the catalog: the studio image (or emoji plate), a soft title
/// gradient, and the calorie folio.
struct MealCard: View {
    @Environment(AppModel.self) private var model
    let entry: FoodEntry
    @State private var revealProgress: Double = 0

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            imagery
                .aspectRatio(1, contentMode: .fill)

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(Int(entry.calories.rounded()))")
                        .font(Theme.statSmall(13))
                        .foregroundStyle(Theme.saffron)
                    Text("KCAL · \(entry.meal.label.uppercased())")
                        .font(.system(size: 8.5, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(Theme.creamFaint)
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .onAppear {
            model.imageEngine.ensure(entry)
            if model.imageEngine.image(for: entry) != nil { revealProgress = 1 }
        }
    }

    @ViewBuilder
    private var imagery: some View {
        let image = model.imageEngine.image(for: entry)
        ZStack {
            Rectangle().fill(Theme.inkHigh)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .grainReveal(progress: revealProgress)
                    .onAppear {
                        if revealProgress < 1 {
                            withAnimation(.easeInOut(duration: 1.2)) { revealProgress = 1 }
                        }
                    }
            } else {
                Text(entry.emoji)
                    .font(.system(size: 40))
                    .opacity(0.85)
            }
        }
    }
}
