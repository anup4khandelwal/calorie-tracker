import SwiftUI
import SwiftData

/// The zoomed-out record: every meal ever logged as one continuous magazine
/// catalog. Days are spreads with ruled headers; meals are plates on the
/// page, arriving with a slight stagger so scrolling feels typeset, not
/// dumped.
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
        GridItem(.flexible(), spacing: Theme.s3 + 2),
        GridItem(.flexible(), spacing: Theme.s3 + 2),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.s8, pinnedViews: []) {
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
        VStack(alignment: .leading, spacing: Theme.s3) {
            FolioRule(text: "MISE · THE RECORD")
            Text("Everything\nyou've plated")
                .font(Theme.masthead(38))
                .foregroundStyle(Theme.cream)
                .lineSpacing(-1)
        }
        .padding(.top, Theme.s6)
    }

    private func daySection(_ dayKey: String, entries: [FoodEntry]) -> some View {
        let total = entries.reduce(0.0) { $0 + $1.calories }
        return VStack(alignment: .leading, spacing: Theme.s4) {
            Button {
                model.open(dayKey: dayKey)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Theme.s2) {
                    Text(DayKey.shortTitle(for: dayKey))
                        .font(.system(size: 19, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                        .offset(y: -4)
                    Text("\(Int(total.rounded()))")
                        .font(Theme.stat(19))
                        .foregroundStyle(Theme.saffron)
                    Text("KCAL")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(1.2)
                        .foregroundStyle(Theme.creamFaint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(Pressable(scale: 0.99))

            LazyVGrid(columns: columns, spacing: Theme.s3 + 2) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        Haptics.shared.tick()
                        model.open(dayKey: dayKey, entryID: entry.id)
                    } label: {
                        MealCard(entry: entry, staggerIndex: index)
                    }
                    .buttonStyle(Pressable(scale: 0.96))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
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
            HStack(spacing: Theme.s2) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, weight: .semibold))
                Text(DayKey.mastheadTitle(for: model.currentDayKey))
                    .font(.system(size: 14, weight: .semibold, design: .serif))
            }
            .foregroundStyle(Theme.cream)
            .padding(.horizontal, Theme.s4 + 2)
            .padding(.vertical, Theme.s3)
            .glassChrome(corner: 24)
        }
        .buttonStyle(Pressable())
        .padding(.bottom, Theme.s3)
    }
}

/// One plate in the catalog: the photograph (or emoji plate), a soft title
/// gradient, and the calorie folio. Arrives with a small stagger.
struct MealCard: View {
    @Environment(AppModel.self) private var model
    let entry: FoodEntry
    var staggerIndex: Int = 0

    @State private var developProgress: Double = 0
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            imagery

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                HStack(spacing: Theme.s1) {
                    Text("\(Int(entry.calories.rounded()))")
                        .font(Theme.statSmall(13))
                        .foregroundStyle(Theme.saffron)
                    Text("KCAL · \(entry.meal.label.uppercased())")
                        .font(.system(size: 8.5, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(Theme.cream.opacity(0.55))
                }
            }
            .padding(Theme.s3)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rTile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rTile, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(Motion.arrive.delay(Double(staggerIndex % 6) * 0.045)) {
                appeared = true
            }
            model.imageEngine.ensure(entry)
            if model.imageEngine.image(for: entry) != nil { developProgress = 1 }
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
                    .filmDevelop(progress: developProgress)
                    .onAppear {
                        if developProgress < 1 {
                            withAnimation(.easeInOut(duration: 1.3)) { developProgress = 1 }
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
