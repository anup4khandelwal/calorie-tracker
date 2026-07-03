import SwiftUI

/// Horizontal pager across days — swipe left toward today, right into the
/// past. Each page is a full conversation thread.
struct DayPagerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.currentDayKey) {
            ForEach(model.pagerDayKeys, id: \.self) { key in
                DayThreadView(dayKey: key)
                    .tag(key)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: model.currentDayKey) {
            Haptics.shared.tick()
        }
    }
}
