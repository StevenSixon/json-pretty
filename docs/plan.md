# 技术方案（Plan）

对应：`docs/spec.md`

## 1. 架构总览

```
┌─────────────────────────── SwiftUI ───────────────────────────┐
│ ContentView                                                    │
│  ├─ TabBarView          (多 Tab 切换 / 新建 / 关闭 / 历史入口)  │
│  └─ HSplitView                                                 │
│      ├─ EditorView  (NSViewRepresentable → NSTextView 可编辑)   │
│      └─ ResultView  (NSViewRepresentable → NSTextView 只读,     │
│                      双击复制 + Toast 反馈)                     │
└────────────────────────────────────────────────────────────────┘
          │ 输入变化 (debounce 300ms)
          ▼
┌─ JSONTabViewModel ──┐    ┌─ JSONProcessor (actor) ─────────────┐
│ 当前 Tab 状态机:     │──▶│ pretty / compact, 后台解析,          │
│ input/output/error/ │◀──│ 错误带行列定位                       │
│ mode/isProcessing   │    └──────────────────────────────────────┘
└─────────────────────┘
          │ Tab 关闭 / App 退出
          ▼
┌─ HistoryStore ──────────────────────────────┐
│ 环形保留最近 10 条, JSON 文件持久化到         │
│ ~/Library/Application Support/JSONPretty/   │
└──────────────────────────────────────────────┘
```

## 2. 模块设计

| 模块 | 文件 | 职责 |
|---|---|---|
| App 入口 | `JSONPrettyApp.swift` | 窗口、Scene、持有 `AppState` |
| 状态 | `AppState.swift` | `tabs: [JSONTab]`、选中 Tab、新建/关闭/恢复 Tab |
| Tab 模型 | `JSONTab.swift` | id、title、input、output、error、mode |
| 解析 | `JSONProcessor.swift` | `actor`，`format(_:mode:)`，输入防抖由 VM 负责 |
| 持久化 | `HistoryStore.swift` | Codable + 原子写文件，容量 10 |
| 编辑器 | `EditorView.swift` | NSTextView 包装：等宽字体、关闭智能引号/替换、大文本友好 |
| 结果区 | `ResultView.swift` | 只读 NSTextView 子类，`clickCount == 2` 时复制全文并发回调 |
| 工具栏 | `ToolbarView.swift` | 格式化/压缩切换、导出、打开文件、历史 popover |
| 导出 | `FileExporter.swift` | NSSavePanel 保存 `.json`；NSOpenPanel 打开 `.json` |

## 3. 关键决策

1. **NSTextView 而非 SwiftUI TextEditor**：TextEditor 在 MB 级文本下滚动/渲染明显卡顿；NSTextView 原生支持大文本。
2. **防抖 + 任务取消**：`Task` 中 `try await Task.sleep(for: .milliseconds(300))`，新输入到来时取消旧 Task，避免大 JSON 连续解析阻塞。
3. **解析在 actor 隔离执行**：`JSONSerialization` 是 CPU 密集同步 API，包进 `actor` 保证离开主线程；10MB 级解析约几十~几百 ms。
4. **错误定位**：`JSONSerialization` 的 `NSError` description 含 "around line X, column Y"，直接透出给用户。
5. **历史记录时机**：Tab 关闭时入栈；App 终止时把所有打开 Tab 也入栈；恢复 = 以该内容新建 Tab。
6. **双击复制**：子类化 NSTextView 拦截 `mouseDown`，`event.clickCount == 2` 时复制 + 回调 UI 显示 "已复制" Toast；单击不拦截，保留文本选择能力。

## 4. 构建与运行

- `swift build` 编译验证
- `Scripts/make-app.sh`：`swift build -c release` 后手工组装 `JSONPretty.app`（Info.plist + 可执行文件），无需 Xcode 工程文件
