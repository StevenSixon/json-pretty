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
        .commands {
            CommandMenu("Tabs") {
                Button("New Tab") { appState.addTab() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Close Tab") { appState.closeSelectedTab() }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Button("Find…") { appState.search.open() }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
