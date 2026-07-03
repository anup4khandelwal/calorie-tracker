import SwiftUI
import SwiftData

/// The zoomed-out record: every meal as a plate floating on the page.
/// No cards, no borders, no gradient overlays — cutout photography with a
/// real drop shadow, a serif caption, and a saffron folio underneath.
/// (Layout tuned against tools/frameaudit/catalog_mock.py.)
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
        GridItem(.flexible(), spacing: Theme.s6),
        GridItem(.flexible(), spacing: Theme.s6),
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
        return VStack(alignment: .leading, spacing: Theme.s5) {
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

            LazyVGrid(columns: columns, spacing: Theme.s6) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    PlateTile(entry: entry, staggerIndex: index)
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

/// One plate on the page. Tapping it launches the hero flight: the plate
/// lifts out of the grid and flies into the day thread as the page dives in.
struct PlateTile: View {
    @Environment(AppModel.self) private var model
    let entry: FoodEntry
    var staggerIndex: Int = 0

    @State private var developProgress: Double = 0
    @State private var appeared = false
    @State private var plateFrame: CGRect = .zero

    var body: some View {
        Button {
            Haptics.shared.tick()
            model.open(
                dayKey: entry.day?.dayKey ?? DayKey.today,
                entryID: entry.id,
                hero: HeroFlight(
                    entryID: entry.id,
                    image: model.imageEngine.image(for: entry),
                    emoji: entry.emoji,
                    from: plateFrame
                )
            )
        } label: {
            VStack(spacing: Theme.s2) {
                PlateImageView(entry: entry, developProgress: developProgress)
                    .aspectRatio(1, contentMode: .fit)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        plateFrame = frame
                    }

                VStack(spacing: 3) {
                    Text(entry.name)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)
                    Text("\(Int(entry.calories.rounded())) KCAL")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(1.2)
                        .foregroundStyle(Theme.saffron.opacity(0.9))
                }
            }
        }
        .buttonStyle(Pressable(scale: 0.95))
        .opacity(model.heroFlight?.entryID == entry.id ? 0 : 1) // hero owns the pixels mid-flight
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(Motion.arrive.delay(Double(staggerIndex % 6) * 0.045)) {
                appeared = true
            }
            model.imageEngine.ensure(entry)
            if model.imageEngine.image(for: entry) != nil {
                developProgress = 1
            } else if model.imageEngine.isGenerating(entry) {
                developProgress = 0
            }
        }
        .onChange(of: model.imageEngine.image(for: entry) == nil) { wasNil, isNil in
            if wasNil && !isNil {
                developProgress = 0
                withAnimation(.easeInOut(duration: 1.3)) { developProgress = 1 }
            }
        }
    }
}

/// The plate itself, in its three lives: a true cutout floating with a drop
/// shadow; an opaque photo circle-cropped so it still reads as a plate; or
/// the emoji on ceramic while nothing is generated yet.
struct PlateImageView: View {
    let entry: FoodEntry
    var developProgress: Double = 1
    @Environment(AppModel.self) private var model

    var body: some View {
        let image = model.imageEngine.image(for: entry)
        ZStack {
            if let image {
                if FoodImageEngine.isCutout(image) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .filmDevelop(progress: developProgress)
                        .shadow(color: .black.opacity(0.50), radius: 16, y: 10)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.cream.opacity(0.10), lineWidth: 1))
                        .filmDevelop(progress: developProgress)
                        .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
                }
            } else {
                emojiPlate
            }
        }
    }

    private var emojiPlate: some View {
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
                .shadow(color: .black.opacity(0.45), radius: 14, y: 9)
            Text(entry.emoji)
                .font(.system(size: 42))
                .opacity(0.9)
        }
        .padding(Theme.s2)
        .modifier(GeneratingBreath(active: model.imageEngine.isGenerating(entry)))
    }
}

/// Still-life shader only while actually generating.
struct GeneratingBreath: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            content.stillLife()
        } else {
            content
        }
    }
}
