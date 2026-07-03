import SwiftUI
import SwiftData

@main
struct MiseApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .preferredColorScheme(.dark)
                .tint(Theme.saffron)
        }
    }
}
