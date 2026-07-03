import SwiftUI

/// Horizontal pager across days — swipe left toward today, right into the
/// past. Each page is a full conversation thread.
///
/// TabView's page style is not lazy, so only pages adjacent to the current
/// day mount their full thread (with its SwiftData query); far pages render
/// a featherweight stand-in until you approach them.
struct DayPagerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let keys = model.pagerDayKeys
        let currentIndex = keys.firstIndex(of: model.currentDayKey) ?? keys.count - 1

        TabView(selection: $model.currentDayKey) {
            ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                Group {
                    if abs(index - currentIndex) <= 1 {
                        DayThreadView(dayKey: key)
                    } else {
                        DayPlaceholder(dayKey: key)
                    }
                }
                .tag(key)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: model.currentDayKey) {
            Haptics.shared.tick()
        }
    }
}

/// What a distant day looks like mid-swipe, before its thread mounts.
private struct DayPlaceholder: View {
    let dayKey: String

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(DayKey.mastheadTitle(for: dayKey))
                .font(Theme.masthead(28))
                .foregroundStyle(Theme.creamFaint)
            Overline(text: "TURNING THE PAGE…")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
