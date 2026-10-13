import Foundation
import Observation

/// 全局应用状态：Tab 集合、选中 Tab、解析调度、历史记录。
@MainActor
@Observable
final class AppState {
    private(set) var tabs: [JSONTab] = [JSONTab()]
    var selectedTabID: JSONTab.ID?
    /// “已复制” Toast 的计数器，视图层监听变化后短暂展示
    private(set) var copyToastToken = 0

    private let processor = JSONProcessor()
    private let historyStore = HistoryStore()
    let launchAtLogin = LaunchAtLoginManager()
    private var formatTasks: [JSONTab.ID: Task<Void, Never>] = [:]

    private static let debounce: Duration = .milliseconds(300)

    init() {
        selectedTabID = tabs.first?.id
    }

    var selectedTab: JSONTab? {
        tabs.first { $0.id == selectedTabID }
    }

    // MARK: - Tab 管理

    func addTab(content: String = "") {
        var tab = JSONTab()
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
            historyStore.push(closed)
        }
        if tabs.isEmpty {
            addTab()
        } else if selectedTabID == id {
            selectedTabID = tabs[min(index, tabs.count - 1)].id
        }
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
            let result: Result<String, Error>
            do {
                result = .success(try await processor.format(input, mode: mode))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled else { return }
            self.applyResult(result, to: id)
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

    var history: [HistoryEntry] {
        historyStore.entries
    }

    func restoreFromHistory(_ entry: HistoryEntry) {
        addTab(content: entry.input)
    }

    func clearHistory() {
        historyStore.clear()
    }

    /// App 退出前调用：把仍打开的 Tab 存入历史
    func snapshotOpenTabs() {
        for tab in tabs where !tab.input.isEmpty {
            historyStore.push(tab)
        }
    }
}
