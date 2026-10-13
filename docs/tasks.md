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
- [x] T11 Tab 增强：双击重命名（FR-3a）、拖动排序（FR-3b）、⌘N/⌘W 快捷键（FR-3c）、T1~Tn 默认编号（FR-3d）；AppStateTests 5 项单测通过
- [x] T12 应用图标：Swift/CoreGraphics 程序化绘制（深色 squircle + 橙青双色花括号 + 白色冒号），iconset 全尺寸原生渲染 → iconutil 生成 .icns，集成进 make-app.sh 与 Info.plist
- [x] T13 大文件性能优化第一轮（裸基准驱动）：
  - 基准定位：解析层 0.16s 非瓶颈；瓶颈在 NSTextView 连续布局全量排版（单行 20s / 多行 4.6s）
  - 双栏改"不换行 + 横向滚动 + 非连续惰性布局"：10MB 单行 1.4s（字形生成下限）、18MB 格式化结果 0.04s
  - 换行方案被基准否决：单段落折行产生数万 line fragment，排版 19.5s
  - 历史记录磁盘 I/O 移出主线程（HistoryStore 改为无状态编解码，AppState 持内存态 + Task.detached 落盘）
- [x] T14 大文件深度优化第二轮（真实 App 实测驱动）：
  - 诊断手段：App 内建 `--bench <file>` 基准模式 + `sample` 抓栈 + 配置矩阵实验（真实窗口环境）
  - 根因：CoreText 对单条巨型行的排版为 O(n²) 病理（每 chunk 重建 CTTypesetter），窗口内赋值 ~38s，TextKit 1/2 同病（栈终点均为 `_ctTypesetter`），任何 NSTextView 配置无解
  - 方案一（离屏快路径）：摘除 documentView → 设置 → 放回，38s → 0.33s
  - 方案二（DisplayChunker 展示分行）：超长行（>64K 字符）按 4096 字符分行显示，编辑器进入锁定展示模式（只读、粘贴整体替换）；复制/双击始终用逻辑原文，选区复制精确剔除插入换行
  - 结果：10MB 文件打开+格式化全流程 **0.78s**（bench 日志实测），20/20 测试通过
- [x] T15 大粘贴路径修复 + UI 自动化验收：
  - 根因：大粘贴走 `insertText` 触发 `scrollRangeToVisible`（插入点移到文末）→ 强制全量排版，实测卡 39.2s
  - 修复：大粘贴改为整体重组文本 + 分行管线离屏写入（绕开 insertText）；粘贴耗时 39.2s → **0.086s**
  - 修复锁定提示跨 Tab 残留（editorLocked 为视图级状态，切换 Tab 时重置）
  - UI 自动化实测（AppleScript 驱动真实 App）：粘贴 10MB → 0.76s 完整渲染、锁定提示正确出现；⌘N 新 Tab 提示消失

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
