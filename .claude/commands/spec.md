---
description: 只产出需求文档 —— subagent 跑 analyst，一道 HITL 关卡；后续接 /ulw {slug} 进设计 + 实现
---

按"只做需求分析"模式处理用户请求：`$ARGUMENTS`

## 调用机制

**subagent**（Agent 工具）。单 agent，不开 team。

## task-slug 生成

启动时自动生成 `{kebab-case-描述}-{YYYY-MM-DD}`：
- 描述部分取 3-5 个英文/拼音关键词
- **不要问用户** slug，直接用并在第一句话告诉用户："本次产出将落在 `docs/specs/{slug}/`"
- 如果 `docs/specs/{slug}/` 已存在 → 提示用户："已有同名 spec，继续会增量更新（保留 Changelog）；要换一个 slug 吗？"

## Pipeline

主会话按以下节点调度。agent 输入/输出遵循 `docs/templates/agent-contract.md`。

1. **analyst** → `requirements.md`
   - 输入：`{task_slug, inputs: [], outputs_required: [docs/specs/{slug}/requirements.md], iteration: 0, previous_feedback: null}`
   - HITL: 等用户"通过"
   - 强制中断: `verdict = needs_more_info`（Open Questions 阻塞下游）

2. **lead 收尾** [deps: 1]
   - 把 `analyst.summary` 呈现给用户
   - 给路径：`docs/specs/{slug}/requirements.md`
   - 建议下一步：`/ulw {slug}` 从已有 requirements 继续（自动跳过 analyst，从 architect 开始）；加 `--auto` 跳过 HITL

## HITL 纪律

- 节点 1 等用户**显式"通过"**才结束
- 用户只补细节没说通过 → 让 analyst 更新 `requirements.md` 后**再问一次**，不要替用户拍板
- `verdict = needs_more_info` → 把 blockers 给用户，等用户回答后让 analyst 再跑一轮（iteration+1，主会话注入 `previous_feedback`）

## 强制中断

- analyst 自己也无法把需求整理到可设计程度（多轮迭代后仍 needs_more_info）→ 暂停，等用户提供更多上下文

## 何时升级

- 用户说"接着设计" / "直接开做" → 提议 `/ulw {slug}`（自动从 architect 开始）
- 用户说"直接跑完不要管我" → 提议 `/ulw {slug} --auto`

只 analyst 一个 agent，不调起其他。
