---
description: 全链路 pipeline —— analyst → architect → developer × N → qa → reviewer → security → wiki-curator → PR；启动选 mode
---

按"全链路 pipeline"模式处理用户请求：`$ARGUMENTS`

## 启动

### 1. 解析 slug

- **空** → 列 `docs/specs/` 下所有子目录（按 mtime 倒序，每项标记已有产出）让用户选。**不要自己挑**；用户说"新建" → 问描述
- **slug 形式**（如 `tiered-pricing-2026-05-17`）且 `docs/specs/{slug}/` 存在 → 复用
- **新描述** → 生成 `{kebab-case}-{YYYY-MM-DD}`；slug 已存在则问"复用 / 换名"

### 2. 选 mode

lead 向用户询问 `mode`：

- `hitl` —— 关卡节点 analyst / architect / wiki-curator 必须询问用户"通过"；节点 4-6 任一异常时主会话给三选（halt / retry / abort，默认 retry）；其余异常即 halt
- `autopilot` —— 节点 4-6 异常自动进自纠错循环；其余异常按 §异常处理 自动裁决

> 自纠错循环两模式共享 3 轮上限，3 轮用尽 → 用户二选 **走 / 停**（默认走）：走 → 进节点 7 + PR body 标注 "3 retries exhausted"；停 → halt（worktree 保留）。详见 §自纠错循环。

### 3. 创建 worktree

git / worktree 操作全部封装在 `.claude/scripts/ulw-*.sh`，主会话只做决策。

1. `bash .claude/scripts/ulw-check.sh {slug}` 探测 `worktree_exists / branch_exists / gh_available / origin_reachable`
2. 前置不满足 → abort（不降级）：`gh` 缺失 → 让用户装；`origin` 不通 → 让用户查网络
3. 冲突处理：
   - 有 worktree → 询问"复用 / 重建 / abort"（重建调 `ulw-worktree-rebuild.sh`）
   - 仅有分支 → 询问"绑定 / 重建 / abort"（绑定调 `ulw-worktree-bind.sh`）
   - 都无 → `ulw-worktree-create.sh`

脚本自动拷贝 `.worktreeinclude` 内文件，stdout 输出绝对路径。主会话 `cd` 进去后 sub-agent 继承 cwd。

### 4. 报告执行计划

第一句话告诉用户：`mode={mode}` / `worktree=.worktrees/ulw-{slug}/ (branch ulw/{slug})` / `产物=docs/specs/{slug}/`。Pipeline 固定跑全程，bug 修复也走需求分析。

## 调用机制

- **TeamCreate**：`team_name="ulw-{slug}"`，主会话 = team lead；结束 `TeamDelete`
- **Agent 必须作为 teammate 调起**（非游离 subagent）：`Agent({...})` 必带 `team_name` + `name`。漏 `name` 会启动游离 subagent，不进 team → idle/Task 信号断裂，pipeline 卡死
- **Agent 输入**：prompt 前置 JSON（必填 `task_slug / mode / inputs / outputs_required`）。developer 子任务额外带 `subtask`；architect retry 额外带 `retry_round`。schema 见 `docs/templates/agent-contract.md`
- **完成信号**：主会话靠两条信号判定 agent 完成 ——（1）cmux 自动发的 `idle_notification`，（2）`docs/specs/{slug}/{outputs_required}` 落盘文件的 frontmatter `verdict`。**agent 禁用 `SendMessage` 传业务内容**；详见 `agent-contract.md` §通信模型
- **状态持久化**：teammate 不跨 session 存活；产出全落 `docs/specs/{slug}/`，session 断也能基于文件续跑
- **teammate 不直接通信**：跨 agent 协作经主会话；下游读上游落盘文件（见 `agent-contract.md`）

## 串行执行模型

- **多 ulw 并行**：独立 worktree + 分支，互不影响
- **单 ulw 内串行**：sub-agent 链式依赖，下游读上游落盘产出
- **agent 自 commit**：落盘 → `bash .claude/scripts/agent-commit.sh <agent> "<summary>"`。主会话不 commit，只在节点 8 push + `gh pr create`
- **自纠错循环**：节点 4-6 任一异常 → architect 重规划 → developer × M → 重跑 4-6；两模式共享 3 轮上限。HITL 每轮异常用户三选（默认 retry），autopilot 自动跑
- **PR review 后续迭代不走 /ulw**：用户在 `.worktrees/ulw-{slug}/` 直接 commit + push 自动更新 PR

## Pipeline

各节点详细行为见 `.claude/agents/{agent}.md`。slug 复用时 agent 自行"文件已存在 → 增量更新 + 顶部 Changelog"。异常 verdict 见 §异常处理。

1. **analyst** → `requirements.md`
2. **architect** [deps: 1] → `design.md`（frontmatter 含 `subtasks` + `retry_rounds: []`）
3. **developer × N** [deps: 2] → 代码 + `implementation.md`
   - 主会话读 `design.md` frontmatter `subtasks`，**按 id 升序**逐个调起，传 `subtask` 对象
   - 每次 commit `[ulw] 3-developer-{id}: {summary}`
4. **qa** [deps: 3] → `qa-report.md`
5. **reviewer** [deps: 4] → `review.md`
6. **security** [deps: 5] → `security.md`（可读 review.md 避重）

> 节点 4-6 是循环段（两模式都进）。**三个全跑完**（不短路）再统一判断：全绿（qa.pass + reviewer ∈ {pass, pass_with_comments} + security.can_merge）→ 进节点 7；任一异常 → §自纠错循环。

7. **wiki-curator** [deps: 4-6 全绿 或 3 轮用尽用户选"走"] → `wiki-report.md` + wiki 文件改动

8. **发起 PR**（无视模式，无 agent，无 self-commit）[deps: 7]
   - 读取来源：`docs/specs/{slug}/*.md` frontmatter + 主体；autopilot 模式额外读 `autopilot-log.md`
   - PR body 顺序：spec 路径 → 需求摘要 → 设计方案 + 备选弃因 → subtasks 清单（初始 + 每轮 retry）+ 各 developer verdict → 自纠错轮次（如进过循环；两 mode 都可能进；从 `design.md` `retry_rounds` 读；3 轮用尽时醒目标注 "3 retries exhausted"）→ 改动文件清单 → qa 测试结果 → reviewer 完整结论 → security 完整结论 + severity_breakdown → wiki 改动清单 → 合并门控判定（pass ⇔ reviewer ∈ {pass, pass_with_comments} AND security = can_merge）→ autopilot 自动裁决记录（autopilot-log 全文）→ ⚠️ 破坏性变更告警（醒目置顶）
   - 把 PR body 写到 `/tmp/ulw-pr-body-{slug}.md`，调 `bash .claude/scripts/ulw-pr-create.sh {slug} /tmp/ulw-pr-body-{slug}.md`（脚本验证分支 + clean check + push + `gh pr create --draft` + 输出 URL）
   - 把 URL 转给用户
   - **清理子 agent pane**：调 `bash .claude/scripts/ulw-close-panes.sh {slug}` 关掉所有 cwd 落在本次 worktree 下的 cmux pane（focused pane 即主会话自己不动）
   - `TeamDelete`；worktree / 分支不自动清理（用户手动用 `ulw-cleanup.sh`）

## 异常处理

### 通用完成检查（每个节点结束都要做）

主会话每收到一条 `idle_notification` 都必须按以下决策表处理，再决定下一步：

| idle 收到 | outputs_required 文件存在 | frontmatter verdict | 主会话动作 |
|---|---|---|---|
| ✅ | ✅ | 在该 agent 枚举内 | 按 verdict 走（详见各 mode 小节） |
| ✅ | ✅ | 缺失 / 非枚举值 | 视为该 agent 的"阻塞类" verdict（如 `analyst.needs_more_info` / `developer.blocked` / `qa.fail` 等），按 mode 处理 |
| ✅ | ❌ | — | 同上（视为阻塞 + agent 没落盘） |

完整通信模型见 `docs/templates/agent-contract.md` §通信模型。本节后续两个 mode 表只列**正常 verdict** 的处理 —— "阻塞类" verdict / 文件缺失走上表回归到对应 mode。

### HITL 模式

| 异常 verdict | 主会话响应 |
|---|---|
| `analyst.needs_more_info` / `architect.needs_user_decision` / `developer-{i}.blocked` / `wiki-curator.needs_human_review` | halt |
| `qa.fail` / `reviewer.request_changes` / `security.cannot_merge`（节点 4-6 全跑完后判断） | 给用户三选：**halt / retry（默认）/ abort**。retry → 进 §自纠错循环 |
| 破坏性变更 | halt |
| 3 轮 retry 用尽（自纠错循环内） | 二选 **走 / 停**（默认走）：走 → 进节点 7；停 → halt |

关卡节点 1（analyst）、2（architect，初始 + retry 都要）、7（wiki-curator）由 agent 自己询问用户"通过"（不由主会话转交）；其余节点不询问。

### Autopilot 模式

原则：**不 halt**（仅 3 轮用尽时打断一次）。

| 异常 verdict | 主会话响应 |
|---|---|
| `analyst.needs_more_info` | 继续节点 2（architect 基于已有 requirements 推进） |
| `architect.needs_user_decision` | 选 architect 推荐方案（无推荐取最保守） |
| `developer-{i}.blocked`（初始或 retry） | 继续下一个 subtask；下游问题由节点 4-6 retry 循环回收 |
| `qa.fail` / `reviewer.request_changes` / `security.cannot_merge`（节点 4-6 全跑完后判断） | 进 §自纠错循环（无交互，max 3 轮） |
| `wiki-curator.needs_human_review` | 跳过该次 wiki 更新，列入 PR body "待人审"，继续节点 8 |
| 破坏性变更 | 也走 PR；PR body 醒目置顶 ⚠️ 块 |
| **3 轮 retry 用尽** | 二选 **走 / 停**（默认走，autopilot 也打断一次）：走 → 进节点 7 + PR body 标注 "3 retries exhausted"；停 → halt |

每次裁决**必须**调：

```bash
bash .claude/scripts/ulw-log-decision.sh {slug} {node} {agent} {verdict} "{decision}" "{reason}" "{blockers 摘要}"
```

脚本 append 一条到 `docs/specs/{slug}/autopilot-log.md` 并 commit。续跑时直接 append；节点 8 PR body 汇总此文件全文。

## 自纠错循环

两模式共享同一机制，仅"轮间是否问用户"不同。

```
进入条件：节点 4-6 全跑完且任一异常（qa.fail OR reviewer.request_changes OR security.cannot_merge）

while round < 3:
  HITL → 主会话给用户三选（halt / retry / abort，默认 retry）；选 halt 或 abort → 退出
  autopilot → 直接进 retry，调 ulw-log-decision.sh 记录"触发 retry"

  round += 1
  调 architect (retry_round=round)：
    读 qa-report.md + review.md + security.md
    在 design.md frontmatter retry_rounds append 一项（trigger + 新 retry subtasks，id 形如 retry-{round}.{index}）
    HITL → architect 关卡询问用户"retry subtasks 这样拆 OK 吗"；用户调整后再问
    autopilot → 不交互
  调 developer × M：按 retry_rounds[round].subtasks **id 升序**调起，agent 名 developer-retry-{round}.{index}
  重跑节点 4-6（各 agent "文件已存在 → 增量更新 + 顶部 Changelog"）
  ※ 三个 check 顺序跑完不短路 —— 给下一轮 architect 完整 blockers，避免抖动

  if 全绿 → 出循环进节点 7

3 轮用尽仍异常 → 用户二选：走 / 停（默认走；autopilot 也打断一次）
  走 → 进节点 7 + 节点 8 PR body 标注 "3 retries exhausted"
  停 → halt（worktree 保留，用户手动接手）
```

- **round 权威源**：design.md frontmatter `retry_rounds` 数组最大 `round`（autopilot-log 仅辅助）。两模式共享同一计数器，混 mode 续跑也不绕过上限
- **单轮成本**：architect 1 + developer × M（通常 1-3）+ qa/reviewer/security 各 1
- **retry 轮 architect.needs_user_decision**：HITL halt；autopilot 选推荐方案 + 记 autopilot-log 不打断循环
- **retry 轮 developer.blocked**：HITL halt；autopilot 记 autopilot-log，继续下一 retry subtask；本轮 check 自然暴露
- **3 轮用尽**：用户二选 走 / 停（默认走）。走 → 节点 7 + PR body 醒目 "3 retries exhausted，疑似设计问题"；停 → halt。worktree 保留，commits 已在分支

## 中断与恢复

worktree 一律保留（halt / 崩溃 / 中断）。`/ulw {slug}` 再次启动 → §3 检测到 worktree → 询问"复用 / 重建 / abort"；复用则基于落盘 spec 文件从中断节点续跑。

## 清理

worktree 永不自动删除。用户手动：

```bash
bash .claude/scripts/ulw-cleanup.sh {slug}                  # 删 worktree，保留分支
bash .claude/scripts/ulw-cleanup.sh {slug} --delete-branch  # 同删本地分支
bash .claude/scripts/ulw-list.sh                            # 列当前所有 ulw worktree
bash .claude/scripts/ulw-close-panes.sh {slug}              # 关本次任务残留 cmux pane（halt 后手动场景）
```

worktree 目录残留但 git 状态未清：`git worktree prune`。

节点 8 正常跑完会自动调 `ulw-close-panes.sh`；中途 halt / 崩溃留下的 pane 用户手动清。
