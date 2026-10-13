# JSON Pretty

macOS 原生 JSON 解析与格式化小工具，SwiftUI + AppKit，零第三方依赖。

## 功能

- 左右双栏：左侧输入，右侧实时自动格式化（300ms 防抖，后台解析）
- 右侧只读，**双击复制**格式化结果
- 多 Tab 独立工作区
- 格式化展开 / 压缩 一键切换
- 打开 / 导出 `.json` 文件
- 大 JSON 高性能（~1.8MB 格式化 < 40ms）
- 最近 10 条历史记录（含已关闭 Tab），可一键恢复

## 构建与运行

```bash
swift build          # 编译
swift test           # 测试
./Scripts/make-app.sh  # 打包 JSONPretty.app
open JSONPretty.app
```

## 文档

- `docs/spec.md` — 需求规格
- `docs/plan.md` — 技术方案
- `docs/tasks.md` — 任务与验收记录
