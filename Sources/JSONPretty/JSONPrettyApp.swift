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
            CommandMenu("标签页") {
                Button("新建标签页") { appState.addTab() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("关闭标签页") { appState.closeSelectedTab() }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Button("查找…") { appState.search.open() }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
