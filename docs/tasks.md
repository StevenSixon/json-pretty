# 任务清单（Tasks）

依据 `docs/plan.md`，按依赖顺序执行：

- [x] T1 工程骨架：Package.swift、App 入口、窗口布局（HSplitView 双栏）
- [x] T2 JSONProcessor：格式化 / 压缩 / 错误定位（actor）
- [x] T3 EditorView + ResultView：NSTextView 包装、只读、双击复制 + Toast
- [x] T4 Tab 系统：新建 / 关闭 / 切换 / 标题推导
- [x] T5 工具栏：模式切换、导出 .json、打开 .json 文件
- [x] T6 HistoryStore：最近 10 条持久化、查看与恢复
- [x] T7 性能：输入防抖、后台解析、大文件验证（1.8MB pretty+compact ≈ 40ms）
- [x] T8 打包脚本 make-app.sh，生成可双击运行的 .app
- [x] T9 全量验收：对照 spec.md 的 FR-1 ~ FR-8（见下表）
- [x] T10 开机启动：LaunchAtLoginManager（SMAppService）+ 工具栏设置菜单开关

## T9 验收记录（2026-10-13）

| FR | 结果 | 证据 |
|---|---|---|
| FR-1 双栏布局 | ✅ | 启动截图：左侧输入 / 右侧结果，默认即双栏 |
| FR-2 只读 + 双击复制 | ✅ | ResultView 只读 NSTextView 子类，双击复制 + Toast |
| FR-3 多 Tab | ✅ | 顶部 Tab 栏 + 新建 / 关闭 / 切换 |
| FR-4 格式化 / 压缩 | ✅ | 单测 testPrettyFormat / testCompactFormat 通过 |
| FR-5 导出文件 | ✅ | NSSavePanel 导出 .json（工具栏“导出”） |
| FR-6 大 JSON 性能 | ✅ | 单测：~1.8MB 格式化 38ms / 压缩 37ms；actor 后台解析 + 300ms 防抖 |
| FR-7 历史记录 | ✅ | HistoryStore 容量 10，原子写 Application Support，popover 恢复 |
| FR-8 错误提示 | ✅ | 单测 testInvalidJSONReportsLocation；UI 红色错误面板含行列定位 |

`swift build` 零警告，`swift test` 6/6 通过。
