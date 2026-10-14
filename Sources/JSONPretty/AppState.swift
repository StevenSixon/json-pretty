import Foundation
import Observation

/// 全局应用状态：Tab 集合、选中 Tab、解析调度、历史记录。
@MainActor
@Observable
final class AppState {
    private(set) var tabs: [JSONTab] = []
    var selectedTabID: JSONTab.ID?
    /// “已复制” Toast 的计数器，视图层监听变化后短暂展示
    private(set) var copyToastToken = 0

    private let processor = JSONProcessor()
    let launchAtLogin = LaunchAtLoginManager()
    let search = SearchController()
    /// 历史记录（主线程内存态；磁盘 I/O 全部在后台执行）
    private(set) var history: [HistoryEntry] = []
    private var formatTasks: [JSONTab.ID: Task<Void, Never>] = [:]
    /// Tab 编号计数器：单调递增，关闭 Tab 不回收
    private var tabCounter = 0

    private static let debounce: Duration = .milliseconds(300)

    init() {
        addTab()
        // 后台加载历史，避免大历史文件阻塞启动
        Task.detached(priority: .utility) {
            let entries = HistoryStore.load()
            await self.applyLoadedHistory(entries)
        }
    }

    private func applyLoadedHistory(_ entries: [HistoryEntry]) {
        history = Array(entries.prefix(HistoryStore.capacity))
    }

    var selectedTab: JSONTab? {
        tabs.first { $0.id == selectedTabID }
    }

    // MARK: - Tab 管理

    func addTab(content: String = "") {
        tabCounter += 1
        var tab = JSONTab(customName: "T\(tabCounter)")
        tab.input = content
        tabs.append(tab)
        selectedTabID = tab.id
        scheduleFormat(for: tab.id, immediate: true)
    }

    func closeTab(_ id: JSONTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        formatTasks[id]?.cancel()
        formatTasks[id] = nil
        let closed = tabs.remove(at: index)
        if !closed.input.isEmpty {
            pushHistory(closed)
        }
        if tabs.isEmpty {
            addTab()
        } else if selectedTabID == id {
            selectedTabID = tabs[min(index, tabs.count - 1)].id
        }
    }

    /// 关闭当前选中的 Tab（⌘W）
    func closeSelectedTab() {
        if let selectedTabID { closeTab(selectedTabID) }
    }

    /// 重命名 Tab；空字符串视为清除自定义名，回退到内容推导
    func renameTab(_ id: JSONTab.ID, name: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tabs[index].customName = trimmed.isEmpty ? nil : trimmed
    }

    /// 拖动排序：把 draggedID 移动到 targetID 所在位置
    func moveTab(_ draggedID: JSONTab.ID, onto targetID: JSONTab.ID) {
        guard draggedID != targetID,
              let from = tabs.firstIndex(where: { $0.id == draggedID }),
              let to = tabs.firstIndex(where: { $0.id == targetID }) else { return }
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)
    }

    // MARK: - 编辑与解析

    func updateInput(_ id: JSONTab.ID, input: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].input = input
        tabs[index].lastModified = Date()
        scheduleFormat(for: id)
    }

    func updateMode(_ id: JSONTab.ID, mode: JSONMode) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].mode = mode
        scheduleFormat(for: id, immediate: true)
    }

    /// 防抖调度：新输入到来取消旧任务；大文件场景避免连续解析阻塞
    private func scheduleFormat(for id: JSONTab.ID, immediate: Bool = false) {
        formatTasks[id]?.cancel()
        formatTasks[id] = Task { [processor, debounce = Self.debounce] in
            if !immediate {
                try? await Task.sleep(for: debounce)
            }
            guard !Task.isCancelled else { return }
            guard let tab = self.tabs.first(where: { $0.id == id }) else { return }
            let input = tab.input, mode = tab.mode
            BenchTimer.mark("解析开始（后台）")
            let result: Result<String, Error>
            do {
                result = .success(try await processor.format(input, mode: mode))
            } catch {
                result = .failure(error)
            }
            BenchTimer.mark("解析完成")
            guard !Task.isCancelled else { return }
            self.applyResult(result, to: id)
            BenchTimer.mark("结果已写回状态（等待 SwiftUI 渲染）")
            // 下一个 runloop 打点：近似渲染提交完成
            await MainActor.run { BenchTimer.mark("主线程 runloop 空闲") }
        }
    }

    private func applyResult(_ result: Result<String, Error>, to id: JSONTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        switch result {
        case .success(let output):
            tabs[index].output = output
            tabs[index].errorMessage = nil
        case .failure(let error):
            tabs[index].output = ""
            tabs[index].errorMessage = error.localizedDescription
        }
    }

    // MARK: - 复制反馈

    func notifyCopied() {
        copyToastToken += 1
    }

    // MARK: - 历史记录

    /// 入栈并后台落盘：内存更新即时生效，编码+写文件移出主线程
    private func pushHistory(_ tab: JSONTab) {
        let entry = HistoryEntry(input: tab.input, mode: tab.mode, savedAt: Date())
        history.insert(entry, at: 0)
        if history.count > HistoryStore.capacity {
            history = Array(history.prefix(HistoryStore.capacity))
        }
        persistHistory()
    }

    private func persistHistory() {
        let snapshot = history
        Task.detached(priority: .utility) {
            HistoryStore.save(snapshot)
        }
    }

    func restoreFromHistory(_ entry: HistoryEntry) {
        addTab(content: entry.input)
    }

    func clearHistory() {
        history = []
        persistHistory()
    }

    /// App 退出前调用：把仍打开的 Tab 存入历史
    func snapshotOpenTabs() {
        for tab in tabs where !tab.input.isEmpty {
            pushHistory(tab)
        }
    }
}
