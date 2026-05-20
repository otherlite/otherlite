---
description: 全链路 pipeline —— analyst → architect → developer → qa → review → wiki-curator；启动选 mode
---

按"全链路 pipeline"模式处理用户请求：`$ARGUMENTS`

## 启动

### 1. 解析 slug

- **空** → 列 `docs/specs/` 下所有子目录（按 mtime 倒序，每项显示 slug + 已有产出 `requirements.md` / `design.md` / `implementation.md` / `qa-report.md` / `review.md` / `security.md` / `wiki-report.md` 是否存在）让用户选。用户说"新建" → 问新描述。**不要自己挑**。
- **已是 slug 形式**（如 `tiered-pricing-2026-05-17`）且 `docs/specs/{slug}/` 存在 → 直接复用（agent 各自负责"文件已存在 → 增量更新 + Changelog"）。
- **是新描述** → 自动生成 `{kebab-case-描述}-{YYYY-MM-DD}`。若 slug 已存在则提示是否复用或换名。

### 2. 选 mode

lead 用 `AskUserQuestion` 问一个问题：

**mode**：`hitl`（每个产物节点等用户"通过"）/ `autopilot`（无 HITL，强制中断红线照常）

### 3. 报告执行计划

第一句话告诉用户：
```
mode = {mode}
产物 → docs/specs/{slug}/
```

Pipeline 固定跑全程：analyst → architect → developer → qa → review → wiki-curator。Bug 修复也走需求分析 —— analyst 会快速产出极简 requirements.md（"修 X bug，无新需求"也算合法产出）。

## 调用机制

**agent teams**（TeamCreate）。`TeamCreate(team_name="ulw-{slug}")`，主会话 = team lead。完成或中断：`TeamDelete`。

teammate 不跨 session 存活；所有产出**必须**落到 `docs/specs/{slug}/`，HITL 关卡或中断之间即使 session 断也能基于文件继续。

## Pipeline

主会话按以下节点调度。所有 agent 输入/输出遵循 `docs/templates/agent-contract.md`。`[if hitl]` 标记的子项仅在 `mode = hitl` 生效。Pipeline 固定全跑，不支持跳过；slug 复用时各 agent 自行处理"文件已存在 → 增量更新 + Changelog"。

1. **analyst** → `requirements.md`
   - HITL [if hitl]: 等用户"通过"
   - 强制中断: `verdict = needs_more_info`

2. **architect** [deps: 1] → `design.md`
   - HITL [if hitl]: 等用户"通过"；多方案让用户选
   - mode = autopilot 且多方案 → architect 自行选推荐并在 design.md 写明"为何选 A 弃 B/C"，verdict = `ready_for_impl`
   - 强制中断: `verdict = needs_user_decision`（不可逆 / 合规 / 真无明显赢家）

3. **developer** [deps: 2] → 代码 + `implementation.md`
   - 迭代: max 3，trigger = `gate.verdict = fail` 或 `qa.needs_iteration = true`
   - 迭代时主会话注入 `previous_feedback = {from, blockers}`
   - on_exceed: halt to user

4. **qa** [deps: 3] → `qa-report.md`
   - 触发迭代: `verdict = fail AND needs_iteration = true` → 回 3

5. **security ‖ reviewer** [deps: 4] → `security.md` + `review.md`
   - 一条消息同时 Agent 两个
   - 强制中断: `security.verdict = cannot_merge` 且含 Critical/High

6. **gate** [deps: 5]
   - 通过条件: `reviewer.verdict ∈ {pass, pass_with_comments} AND security.verdict = can_merge`
   - 否则:
     - mode = hitl → 给用户 blockers，问是否回 3 迭代（消耗 1 次配额）
     - mode = autopilot → 直接 halt to user（首次失败就停下汇报）

7. **wiki-curator** [deps: 6=pass] → `wiki-report.md` + wiki 文件改动
   - HITL [if hitl]: 等用户"通过"才落盘（主会话调起时传 `hitl=true`）
   - mode = autopilot → 直接落盘（传 `hitl=false`）
   - 强制中断: `verdict = needs_human_review`

8. **lead 汇报** [deps: 7]
   - 必出（不可简化）：
     - spec 目录路径
     - 需求摘要（analyst.summary）
     - 选定的设计方案 + 备选方案被弃原因（如有）
     - developer 改动文件清单
     - qa 测试结果（通过/失败/跳过）
     - **security 完整结论** + severity_breakdown（Critical/High 全文，Medium/Low 计数）
     - **reviewer 完整结论**（阻塞 / 应该修 / 建议 分组）
     - **wiki 改动清单**（wiki_changes.{modified, created, skipped}）
   - 汇报结束后 `TeamDelete`

## HITL 纪律（mode = hitl 时生效）

- 节点 1、2、7 必须等用户**显式"通过"**才能进下一步
- 用户只补细节没说通过 → 让对应 agent 更新文件后**再问一次**
- 节点 3、4 不设关卡；节点 5 完成后向用户汇报但不阻塞 gate
- 节点 7 用户可选"暂停"跳过 wiki 更新（其余节点已固定全跑）

## 强制中断（无视模式）

- 任一 agent 返回 verdict ∈ `{needs_more_info, needs_user_decision, request_changes, cannot_merge, needs_human_review}` 且无法在迭代上限内解决
- 迭代次数耗尽（developer max=3）
- 破坏性变更（破坏现有 API / 数据丢失 / 不可回滚 migration）—— 由发现的 agent 通过 `blockers` 上报，对应 verdict 触发本段第 1 条

中断时：列 blockers，等用户。
