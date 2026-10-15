import SwiftUI

/// 主界面：Tab 栏 + 工具栏 + 左右分栏
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showHistory = false
    @State private var showCopyToast = false
    @State private var editingTabID: JSONTab.ID?
    @State private var renameDraft = ""
    @State private var editorLocked = false
    @FocusState private var renameFocused: Bool
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            tabBar
            Divider()
            toolbar
            if appState.search.isVisible {
                Divider()
                searchBar
            }
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
        // 锁定标记是“当前 Tab”的状态：切换/新建 Tab 时重置，
        // 若新 Tab 仍是大文件，编辑器分行后会通过 onLockChange 重新置位
        .onChange(of: appState.selectedTabID) { _, _ in
            editorLocked = false
        }
        // 搜索栏打开时自动聚焦输入框，并全选已有查询词便于替换输入
        .onChange(of: appState.search.isVisible) { _, visible in
            if visible {
                searchFocused = true
                DispatchQueue.main.async {
                    (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
                }
            }
        }
        .task {
            // 基准模式：--bench <文件> 启动后自动载入并全流程计时
            guard let path = BenchTimer.filePath, let tab = appState.selectedTab else { return }
            BenchTimer.mark("基准开始：读取文件 \(path)")
            let content = await Task.detached(priority: .userInitiated) {
                try? String(contentsOfFile: path, encoding: .utf8)
            }.value
            BenchTimer.mark("文件读取完成（\(content.map { $0.utf8.count / 1_000_000 } ?? 0)MB）")
            if let content {
                appState.updateInput(tab.id, input: content)
                BenchTimer.mark("输入已写回状态（等待 SwiftUI 渲染编辑器）")
                await MainActor.run { BenchTimer.mark("主线程 runloop 空闲（编辑器）") }
            }
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

    // MARK: - 搜索栏

    private var searchBar: some View {
        let search = appState.search
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索（作用于：\(search.activePane == .editor ? "左侧输入" : "右侧结果")）",
                      text: Binding(
                        get: { search.query },
                        set: { search.setQuery($0) }
                      ))
                .textFieldStyle(.plain)
                .frame(maxWidth: 360)
                .focused($searchFocused)
                .onSubmit { search.next() }      // Enter = 下一个
                .onExitCommand { search.close() } // Esc = 关闭

            if !search.query.isEmpty {
                Text(search.activeMatchCount == 0
                     ? "无结果"
                     : "\(min(search.currentIndex + 1, search.activeMatchCount))/\(search.activeMatchCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // 精确 / 模糊匹配切换
            Button { search.toggleFuzzy() } label: {
                Text(search.fuzzy ? "模糊" : "精确")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(search.fuzzy ? Color.accentColor.opacity(0.2) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .help(search.fuzzy ? "模糊匹配：字符按序出现即命中（点击切回精确）" : "精确匹配：子串查找（点击切换模糊）")

            Button { search.previous() } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(search.activeMatchCount == 0)
            .help("上一个")

            Button { search.next() } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(search.activeMatchCount == 0)
            .help("下一个（Enter）")

            Spacer()

            Button { search.close() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("关闭（Esc）")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    // MARK: - 左右分栏

    private var splitContent: some View {
        HSplitView {
            // 左：输入
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    paneHeader("输入 JSON", systemImage: "pencil")
                    if editorLocked {
                        Label("大文件展示模式：已锁定编辑，粘贴可整体替换", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                if let tab = appState.selectedTab {
                    EditorView(text: Binding(
                        get: { tab.input },
                        set: { appState.updateInput(tab.id, input: $0) }
                    ), onLockChange: { locked in
                        editorLocked = locked
                    }, search: appState.search)
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
                ResultView(text: tab.output, onCopy: {
                    appState.notifyCopied()
                }, search: appState.search)
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
