---
description: 只产出需求 + 设计文档，不写代码 —— subagent 串行跑 analyst → architect，两道 HITL 关卡都保留
---

按"只出方案不实现"模式处理用户请求：`$ARGUMENTS`

## 调用机制

**subagent**（Agent 工具）。

## task-slug 生成

启动时根据用户请求自动生成：
- 格式：`{kebab-case-描述}-{YYYY-MM-DD}`
- 示例：用户输入 "做个用户分级定价" → slug = `tiered-pricing-2026-05-17`
- 描述部分取 3-5 个英文/拼音关键词，能识别即可
- **不要问用户** slug，直接用并在第一句话告诉用户："本次产出将落在 `docs/specs/{slug}/`"
- 如果 `docs/specs/{slug}/` 已存在 → 提示用户："已有同名 spec，继续会增量更新（保留 Changelog）；要换一个 slug 吗？"

## 流程

1. 调起 `requirements-analyst`。prompt 模板：
   > 任务：{用户原始请求}
   > task-slug: {slug}
   > 完成后把需求文档写到 `docs/specs/{slug}/requirements.md` 并返回摘要。

2. analyst 返回 → 主会话把文档关键内容呈现给用户 → **HITL 关卡 1**：等用户明确"通过"。

3. 用户通过后，调起 `architect`。prompt 模板：
   > task-slug: {slug}
   > 读 `docs/specs/{slug}/requirements.md` 作为输入，产出设计写到 `docs/specs/{slug}/design.md` 并返回摘要。

4. architect 返回 → 呈现给用户 → **HITL 关卡 2**：等用户明确"通过"。

5. 结束。**不调起** developer / qa / security / reviewer。最后给用户两份文件路径。

## 何时升级到 `/ulw`

用户说"开做" → 提议 `/ulw {slug}`，从已确认的需求 + 设计继续，不重跑前两步。
