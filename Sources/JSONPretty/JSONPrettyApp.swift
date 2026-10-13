import SwiftUI

@main
struct JSONPrettyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        Window("JSON Pretty", id: "main") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1200, height: 760)
    }
}
