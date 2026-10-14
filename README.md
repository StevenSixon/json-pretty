# JSON Pretty

macOS 原生 JSON 解析与格式化工具。SwiftUI + AppKit，零第三方依赖。

## 功能

- **左右双栏**：左侧输入，右侧实时自动格式化（300ms 防抖 + 后台 actor 解析）
- **双击复制**：右侧结果区只读，双击复制格式化后的完整内容（Toast 反馈）
- **多 Tab 工作区**：
  - 默认命名 T1、T2…Tn，编号单调递增
  - 双击 Tab 名称重命名
  - 拖动 Tab 排序
  - `⌘N` 新建 Tab、`⌘W` 关闭当前 Tab
- **格式化 / 压缩**一键切换，支持打开与导出 `.json` 文件
- **历史记录**：最近 10 个 Tab 内容自动保留（含已关闭 Tab），随时恢复
- **开机启动**：设置菜单一键注册/注销登录项（SMAppService）
- **搜索**：`⌘F` 唤起搜索栏，匹配高亮 + 自动滚动定位，Enter/按钮上下导航，作用于当前聚焦面板（左/右栏）
- **错误定位**：非法 JSON 显示带行列信息的错误提示
- **大文件高性能**：10MB JSON 打开/粘贴到格式化完成 **< 1s**（见下）

## 大文件策略

CoreText 对单条巨型行（如压缩后的 10MB JSON）的排版是 O(n²) 病理（实测 ~40s，TextKit 1/2 同病）。本应用的应对：

- **非连续惰性布局**：只排版可视区域
- **离屏写入快路径**：大文本先摘除视图、设置内容、再放回（38s → 0.33s）
- **展示分行（DisplayChunker）**：超长行（>64K 字符）按 4096 字符分行显示，规避巨型行病理；复制始终输出逻辑原文
- **锁定展示模式**：含超长行的内容只读展示、粘贴整体替换（单行巨文本内嵌编辑是所有 NSTextView 系编辑器的物理极限）

实测数据（10MB 单行 JSON，M 系列芯片）：

```
读取 0.05s → 编辑器写入 0.12s → 后台格式化 0.67s → 结果写入 0.77s
大粘贴 0.086s（insertText 原路径为 39.2s）
```

## 构建与运行

```bash
swift build              # 编译
swift test               # 20+ 项测试（含 10MB 性能基准）
./Scripts/make-app.sh    # 打包 JSONPretty.app（自动生成图标）
open JSONPretty.app
```

### 基准模式

```bash
./JSONPretty.app/Contents/MacOS/JSONPretty --bench /path/to/large.json
```

启动后自动载入文件并打印分阶段耗时（读取/编辑器写入/解析/结果渲染/主线程空闲），用于性能诊断与回归验证。

### 测试数据生成

```bash
python3 Scripts/generate-test-json.py testdata/large-10mb.json   # ~10MB，2.4 万条记录
```

## 项目结构

```
Sources/JSONPretty/
├── JSONPrettyApp.swift        # 入口、⌘N/⌘W 命令
├── AppState.swift             # Tab 管理、防抖调度、历史（@MainActor + @Observable）
├── Models/JSONTab.swift       # Tab 模型（自定义名 + 内容推导标题）
├── Services/
│   ├── JSONProcessor.swift    # actor 隔离的解析/格式化/压缩
│   ├── DisplayChunker.swift   # 展示层分行（规避 CoreText 巨型行病理）
│   ├── HistoryStore.swift     # 历史编解码（后台 I/O）
│   ├── LaunchAtLoginManager.swift  # 开机启动（SMAppService）
│   ├── FileExporter.swift     # 打开/导出 .json
│   └── BenchTimer.swift       # --bench 基准打点
└── Views/
    ├── ContentView.swift      # Tab 栏 + 工具栏 + 双栏布局
    ├── EditorView.swift       # 编辑器（NSTextView + 大粘贴/锁定模式）
    ├── ResultView.swift       # 结果区（只读、双击复制、选区精确复制）
    └── HistoryView.swift      # 历史记录浮层
```

## 文档

- `docs/spec.md` — 需求规格（FR-1 ~ FR-9）
- `docs/plan.md` — 技术方案与关键决策
- `docs/tasks.md` — 任务清单与验收记录（含性能优化的完整分析过程）

## 已知边界

- 锁定展示模式下不能直接编辑巨型文件内容（粘贴可整体替换）
- 大粘贴（>1MB）不支持 ⌘Z 撤销；普通编辑撤销不受影响
