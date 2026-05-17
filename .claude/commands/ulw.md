---
description: Ultra-Long Workflow —— agent teams 全流水线，带 HITL 关卡：analyst → architect → developer → qa → security + reviewer
---

按"完整 HITL 流水线"模式处理用户请求：`$ARGUMENTS`

## 调用机制

**agent teams**（通过 TeamCreate）。理由：长链条 + 末段 security/reviewer 可并行，team lead（即主会话）调度更顺。

注意已知限制：teammate 不跨 session 存活。所有产出**必须**落到 `docs/specs/{slug}/`，HITL 关卡之间即使 session 中断，下次仍能基于文件继续。

## task-slug 生成

同 `/spec`：启动时自动生成 `{kebab-case-描述}-{YYYY-MM-DD}`，第一句话告知用户路径。已存在则提示是否复用或换名。

用户参数若已是 slug 形式（例如 `/ulw tiered-pricing-2026-05-17`）且 `docs/specs/{slug}/` 存在 → 直接复用，从最早缺失的产出文件开始跑（例如 design.md 已有但 implementation.md 没有 → 从 developer 开始）。

## 流程（严格顺序）

启动团队：
- `TeamCreate(team_name="ulw-{slug}")`
- 主会话 = team lead

依次（每一步通过 Agent 调起对应 teammate）：

1. **requirements-analyst** → 产出 `requirements.md`
   - **HITL 关卡 1**：呈现需求摘要给用户，等"通过"
2. **architect** → 产出 `design.md`
   - **HITL 关卡 2**：呈现设计摘要给用户，等"通过"；多方案让用户选
3. **developer** → 写代码 + 产出 `implementation.md`
4. **qa** → 产出 `qa-report.md`
5. **security + reviewer** —— **并行**（一条消息里同时 Agent 两个）→ 产出 `security.md` 和 `review.md`
6. **检查双通过**：
   - reviewer 结论 = **通过** 或 **带评论通过**
   - security 结论 = **可以合并**
   - 任一未通过 → **跳过步骤 7**，把审查结论给用户决定是否让 developer 二次迭代
7. **wiki-curator** —— 调起 `wiki-curator` agent，传 `task-slug` 和 `hitl=true`，把 spec 编译进 docs/features /api /architecture
   - **HITL 关卡 3**：呈现 wiki 改动清单给用户，等"通过"才落盘
8. 主会话汇总：审查结论 + wiki 改动摘要 → 给用户最终判定

完成或中断时：`TeamDelete(team_name="ulw-{slug}")`，避免残留 team 配置。

## HITL 纪律

- 关卡 1、2、3 必须等用户**显式"通过"**才能进下一步。
- 用户只补细节没说通过 → 让对应 agent 更新文件后**再问一次**。
- developer/qa 阶段不设关卡；security + reviewer 完成后向用户汇报。
- wiki-curator 关卡 3 是最后一道把关，用户可选"暂停"跳过 wiki 更新（spec 已落盘可后续手动重跑）。

## 强制中断（无视任何策略）

- analyst 报告 Open Questions 阻塞下游
- architect 报告多方案无明显赢家 / 涉及不可逆决策
- security 报 Critical 或 High
- reviewer 给"要求修改"

## 中途切换

- 用户"够了，直接做" → 提议切到 `/autopilot {slug}`，从当前阶段继续。
- 用户"先不做" → `TeamDelete`，保留 `docs/specs/{slug}/` 作下次输入。
