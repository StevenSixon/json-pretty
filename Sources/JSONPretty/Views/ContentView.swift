import SwiftUI

/// 主界面：Tab 栏 + 工具栏 + 左右分栏
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showHistory = false
    @State private var showCopyToast = false
    @State private var editingTabID: JSONTab.ID?
    @State private var renameDraft = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            tabBar
            Divider()
            toolbar
            Divider()
            splitContent
        }
        .overlay(alignment: .top) {
            if showCopyToast {
                Label("已复制到剪贴板", systemImage: "checkmark.circle.fill")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 48)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: appState.copyToastToken) { _, _ in
            withAnimation { showCopyToast = true }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation { showCopyToast = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            appState.snapshotOpenTabs()
        }
    }

    // MARK: - Tab 栏

    private var tabBar: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(appState.tabs) { tab in
                        tabItem(tab)
                    }
                }
                .padding(.horizontal, 8)
            }

            Button {
                appState.addTab()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("新建 Tab")
            .padding(.trailing, 8)
        }
        .frame(height: 34)
        .background(.bar)
    }

    private func tabItem(_ tab: JSONTab) -> some View {
        let isSelected = tab.id == appState.selectedTabID
        return HStack(spacing: 6) {
            if editingTabID == tab.id {
                TextField("", text: $renameDraft)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 90)
                    .focused($renameFocused)
                    .onSubmit { commitRename(tab.id) }
                    .onChange(of: renameFocused) { _, focused in
                        if !focused { commitRename(tab.id) }
                    }
            } else {
                Text(tab.title)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: 140)
            }

            Button {
                appState.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(isSelected ? 1 : 0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            startRename(tab)
        }
        .onTapGesture(count: 1) {
            appState.selectedTabID = tab.id
        }
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let draggedID = UUID(uuidString: raw) else { return false }
            appState.moveTab(draggedID, onto: tab.id)
            return true
        }
    }

    private func startRename(_ tab: JSONTab) {
        appState.selectedTabID = tab.id
        renameDraft = tab.title
        editingTabID = tab.id
        renameFocused = true
    }

    private func commitRename(_ id: JSONTab.ID) {
        guard editingTabID == id else { return }
        appState.renameTab(id, name: renameDraft)
        editingTabID = nil
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 12) {
            if let tab = appState.selectedTab {
                Picker("模式", selection: Binding(
                    get: { tab.mode },
                    set: { appState.updateMode(tab.id, mode: $0) }
                )) {
                    ForEach(JSONMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            Button {
                Task {
                    if let content = await FileExporter.openJSONFile() {
                        if let tab = appState.selectedTab {
                            appState.updateInput(tab.id, input: content)
                        }
                    }
                }
            } label: {
                Label("打开文件", systemImage: "folder")
            }
            .help("打开 .json 文件到当前 Tab")

            Button {
                if let tab = appState.selectedTab {
                    FileExporter.saveJSONFile(tab.output)
                }
            } label: {
                Label("导出", systemImage: "square.and.arrow.down")
            }
            .disabled(appState.selectedTab?.output.isEmpty ?? true)
            .help("将右侧结果保存为 .json 文件")

            Spacer()

            Button {
                showHistory.toggle()
            } label: {
                Label("历史", systemImage: "clock.arrow.circlepath")
            }
            .popover(isPresented: $showHistory) {
                HistoryView()
            }
            .help("查看最近 10 条记录")

            Menu {
                Toggle("开机启动", isOn: Binding(
                    get: { appState.launchAtLogin.isEnabled },
                    set: { appState.launchAtLogin.setEnabled($0) }
                ))
                if let error = appState.launchAtLogin.lastError {
                    Text(error)
                }
            } label: {
                Image(systemName: "gear")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("设置")
            .onAppear { appState.launchAtLogin.refresh() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 左右分栏

    private var splitContent: some View {
        HSplitView {
            // 左：输入
            VStack(alignment: .leading, spacing: 4) {
                paneHeader("输入 JSON", systemImage: "pencil")
                if let tab = appState.selectedTab {
                    EditorView(text: Binding(
                        get: { tab.input },
                        set: { appState.updateInput(tab.id, input: $0) }
                    ))
                    .id(tab.id)
                }
            }
            .frame(minWidth: 300)

            // 右：结果（只读）
            VStack(alignment: .leading, spacing: 4) {
                paneHeader("结果（双击复制）", systemImage: "doc.on.doc")
                resultPane
            }
            .frame(minWidth: 300)
        }
        .padding(8)
    }

    @ViewBuilder
    private var resultPane: some View {
        if let tab = appState.selectedTab {
            if let error = tab.errorMessage {
                ScrollView {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color.red.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8))
            } else {
                ResultView(text: tab.output) {
                    appState.notifyCopied()
                }
                .id(tab.id)
            }
        }
    }

    private func paneHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}
