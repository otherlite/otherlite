---
description: 系统结构视角的 wiki —— 包边界、关键流程、数据模型、跨服务通信
domain: meta
---

# docs/architecture/

每个 markdown 文件描述**一块系统结构**：包边界、关键流程、数据模型、跨服务通信、关键决策（ADR）。

## 写谁

- 工程师做改动前理解系统全貌
- 评审者判断"这个改动符不符合现有架构"

## 维护方

- 主要由 `wiki-curator` 自动更新（来源于 spec 的 design.md）
- 重大架构决策（ADR）由 architect 手写，放在 `adr/` 子目录
- 手写补充放在 HUMAN 保护块内

## 文件命名

按系统模块或主题：`{topic}.md`。例如 `payment-flow.md`、`package-boundaries.md`、`auth-architecture.md`。

ADR：`adr/{NNNN}-{kebab-title}.md`，编号递增。

## frontmatter 必填

```yaml
---
description: 一句话主题说明
domain: architecture
last_updated_by_spec: {最近一次更新本页的 task-slug}
---
```
