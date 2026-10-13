# JSON Pretty — macOS JSON 解析与格式化工具

## 1. 产品定位
一款 macOS 桌面小工具，提供 JSON 的解析、格式化、压缩与导出能力。
界面简洁，响应迅速，支持大体积 JSON。

## 2. 功能需求（FR）

| 编号 | 需求 | 验收标准 |
|---|---|---|
| FR-1 | 双栏布局 | 打开 App 默认展示左右分栏：左侧为 JSON 输入编辑区，右侧自动实时展示格式化结果 |
| FR-2 | 只读结果区 | 右侧栏不可编辑；双击右侧结果区自动将格式化后的 JSON 复制到剪贴板，并给出视觉反馈 |
| FR-3 | 多 Tab | 支持新建/关闭多个 Tab，每个 Tab 独立维护左右栏内容与状态 |
| FR-4 | 格式化 / 压缩 | 支持格式化展开（pretty print，2 空格缩进）与压缩（去除所有空白）两种模式切换 |
| FR-5 | 导出文件 | 支持将右侧结果（格式化或压缩后）下载保存为 `.json` 文件（NSSavePanel） |
| FR-6 | 大 JSON 性能 | 解析与格式化在后台线程执行；输入防抖；支持粘贴 / 打开大文件（10MB+ 不卡死 UI） |
| FR-7 | 历史记录 | 自动保留最近 10 个 Tab 的最新内容（含已关闭的 Tab），可随时查看并一键重新加载为新 Tab |
| FR-8 | 错误提示 | JSON 非法时，右侧栏展示错误信息（含行列位置提示），不崩溃、不清空输入 |
| FR-9 | 开机启动 | 设置菜单中提供“开机启动”开关，基于 SMAppService 注册/注销，状态与系统设置同步 |

## 3. 非功能需求（NFR）

- **性能**：JSON 解析基于 `JSONSerialization`（原生 C 实现）；输入防抖 300ms；解析/格式化在后台 actor 执行，结果回主线程渲染。
- **大文本**：编辑器与结果区均使用 `NSTextView`（AppKit 包装），避免 SwiftUI `TextEditor` 在大文本下的性能问题。
- **持久化**：历史记录存储于 `~/Library/Application Support/JSONPretty/history.json`。
- **UI**：macOS 原生 SwiftUI + AppKit 混合；等宽字体；跟随系统深浅色。

## 4. 技术选型

- 语言/框架：Swift 6 + SwiftUI（界面）+ AppKit（NSTextView 包装）
- 构建：Swift Package Manager 可执行目标 + 打包脚本生成 `.app`
- 最低系统：macOS 14
- 无第三方依赖

## 5. 范围外（Out of Scope）

- JSON 树形折叠视图（后续迭代）
- JSONPath / JMESPath 查询
- iCloud 同步
