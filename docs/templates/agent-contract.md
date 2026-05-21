---
description: agent 交付契约 —— 产物 frontmatter / 返回消息 / 输入消息的 schema，verdict 枚举，self-commit 与一致性铁律
domain: templates
---

# Agent 交付契约

所有 agent 与主会话（team lead）之间的通信遵循本契约。目的：让合并门控判定、HITL 中断**靠结构化字段**，不靠 LLM 解析自然语言。

> Pipeline 节点全程串行（developer 拆多个独立子任务）。qa/reviewer/security 异常进自纠错循环（两 mode 共享 3 轮上限；HITL 每轮异常用户三选触发，autopilot 自动；详见 `.claude/commands/ulw.md` §自纠错循环）。3 轮用尽 → 用户二选 走/停（默认走，进节点 7+PR；停=halt）。其余异常 HITL halt，autopilot 按表自动裁决。

## 三种 schema

### 1. 产物文件 frontmatter（单一事实源）

每个 agent 落盘的产物（`docs/specs/{slug}/*.md`）**必须**带以下 frontmatter：

```yaml
---
agent: reviewer                          # agent 名（见下方枚举）
task_slug: tiered-pricing-2026-05-17     # 任务 slug
verdict: pass_with_comments              # 该 agent 的判定（枚举见下方）
blockers: []                             # 阻塞下游的事项数组，无则空数组
artifact_path: docs/specs/tiered-pricing-2026-05-17/review.md  # 本文件相对仓库根的路径
summary: 代码质量整体好，3 处可读性改进建议   # 一句话摘要（≤ 80 字）
created_at: 2026-05-20T10:30:00Z         # ISO 8601
---
```

字段语义：

| 字段 | 类型 | 是否必填 | 说明 |
|---|---|---|---|
| `agent` | string | ✅ | 见下方 agent 枚举（developer 子任务用 `developer-{subtask.id}`：初始如 `developer-2`，retry 如 `developer-retry-1.1`） |
| `task_slug` | string | ✅ | 来自主会话输入 |
| `verdict` | enum | ✅ | 按 agent 不同，枚举不同（见下方） |
| `blockers` | string[] | ✅（无则 `[]`） | 阻塞下游的条目。`verdict` 表示态度，`blockers` 给细节 |
| `artifact_path` | string | ✅ | 仓库相对路径，方便机器跳转 |
| `summary` | string | ✅ | ≤ 80 字，给主会话向用户汇报用 |
| `created_at` | ISO 8601 | ✅ | 落盘时间 |

主体（frontmatter 之后的 markdown）按各 agent 自己的 template 约束（`prd.md`、`design-doc.md`、`code-review.md` 等）。

**扩展字段**：除上表 7 个契约字段外，agent 可加自家业务字段（如 `type` / `affects_docs` / `status` / `last_updated_by_spec` / `subtasks`），下游消费者按需读取。约束：

- 不可与契约字段同名
- 不可改契约字段语义
- 加新业务字段前先想清楚谁会消费

下表是各 agent 已在用的业务字段：

| Agent | 业务字段 | 消费方 |
|---|---|---|
| analyst | `type: requirements` · `affects_docs[]` · `status: draft\|approved` | wiki-curator |
| architect | `type: design` · `affects_docs[]` · `status: draft\|approved` · `subtasks: [{id: int, title, files, summary, acceptance}]` · `retry_rounds: [{round: int, trigger: {qa, reviewer, security}, subtasks: [{id: "retry-N.M", ...}]}]` | wiki-curator + 主会话（subtasks 与 retry_rounds[].subtasks 驱动 developer 循环） |
| developer | `type: implementation` · `subtask_id: int \| string` | — |
| qa | `type: qa-report` | — |
| reviewer | `type: review` | 主会话（节点 8 PR body 合并门控判定用 `verdict`） |
| security | `type: security` · `severity_breakdown: {critical: 0, high: 0, medium: 0, low: 0}` | 主会话 |
| wiki-curator | 写入 wiki 文件时用 wiki 自身 frontmatter（`description` / `domain` / `last_updated_by_spec`），契约 frontmatter 只用于"操作报告"摘要 |

### 2. agent 返回给主会话的消息（frontmatter 的 JSON 副本）

agent 完成任务后，**最后一条消息必须**是 JSON：

```json
{
  "agent": "reviewer",
  "task_slug": "tiered-pricing-2026-05-17",
  "verdict": "pass_with_comments",
  "blockers": [],
  "artifact_path": "docs/specs/tiered-pricing-2026-05-17/review.md",
  "summary": "代码质量整体好，3 处可读性改进建议"
}
```

**铁律**：JSON 字段值必须与落盘 frontmatter **逐字段相等**。两者不一致 → agent 输出无效，主会话拒收，要求重做。

### 3. 主会话给 agent 的输入消息

主会话调起 agent 时（`Agent({...})` 的 prompt 部分）前置一段 JSON：

```json
{
  "task_slug": "tiered-pricing-2026-05-17",
  "mode": "hitl",
  "inputs": [
    "docs/specs/tiered-pricing-2026-05-17/requirements.md",
    "docs/specs/tiered-pricing-2026-05-17/design.md"
  ],
  "outputs_required": ["docs/specs/tiered-pricing-2026-05-17/review.md"]
}
```

developer 子任务额外带 subtask 字段：

```json
{
  "task_slug": "...",
  "mode": "autopilot",
  "inputs": ["docs/specs/.../design.md"],
  "outputs_required": ["docs/specs/.../implementation.md"],
  "subtask": {
    "id": 2,
    "title": "添加 Foo POST API",
    "files": ["src/api/foo.ts", "src/routes.ts"],
    "summary": "实现 POST /foo 路由",
    "acceptance": "请求体 schema 校验，鉴权中间件，返回 201"
  }
}
```

architect retry 调用额外带 `retry_round` 字段（自纠错循环 retry 轮触发，两 mode 共用）：

```json
{
  "task_slug": "...",
  "mode": "hitl",                       // 或 "autopilot"
  "inputs": [
    "docs/specs/.../design.md",
    "docs/specs/.../qa-report.md",
    "docs/specs/.../review.md",
    "docs/specs/.../security.md"
  ],
  "outputs_required": ["docs/specs/.../design.md"],
  "retry_round": 1
}
```

developer retry 子任务：`subtask.id` 为字符串 `retry-{round}.{index}`，其余字段相同。

输入消息字段语义：

| 字段 | 类型 | 说明 |
|---|---|---|
| `task_slug` | string | 任务标识 |
| `mode` | `"hitl"` \| `"autopilot"` | 由 `/ulw` 启动时选定。`hitl` → agent 关卡节点必须向用户询问拿到通过；`autopilot` → 不交互。analyst / architect / wiki-curator 必读 |
| `inputs` | string[] | agent **必读**的文件路径清单 |
| `outputs_required` | string[] | agent **必须落盘**的文件路径清单 |
| `subtask` | object \| 缺省 | 仅 developer 子任务调用时带；含 id（int 或字符串）/ title / files / summary / acceptance |
| `retry_round` | int ≥ 1 \| 缺省 | architect 在自纠错循环 retry 轮被调起时带（两 mode 共用）。omit = 初始阶段；禁用 `0` |

## Agent 枚举与 verdict 枚举

| agent | verdict 枚举 |
|---|---|
| `analyst` | `ready_for_design` / `needs_more_info` |
| `architect` | `ready_for_impl` / `needs_user_decision` |
| `developer`（子任务调用名 `developer-{subtask.id}`，初始如 `developer-2`，retry 如 `developer-retry-1.1`） | `implementation_complete` / `blocked` |
| `qa` | `pass` / `fail` |
| `reviewer` | `pass` / `pass_with_comments` / `request_changes` |
| `security` | `can_merge` / `cannot_merge` |
| `wiki-curator` | `ready_to_apply` / `needs_human_review` |

新增 verdict 值需要先改本文件 + 同步改对应 agent prompt，禁止 agent 私自创造枚举值。

## 合并门控判定（衍生值，非 pipeline 节点）

主会话在节点 8 PR body 中**衍生**一个综合判定，不读产物主体：

```
merge_gate.pass ⇔
  reviewer.verdict ∈ {pass, pass_with_comments}
  AND security.verdict == can_merge
```

不通过时进 §自纠错循环（两 mode 共享，HITL 每轮异常用户三选，autopilot 自动）；3 轮用尽 → 用户二选 走/停（默认走，进节点 7+PR 标注 exhausted；停=halt）。

这是 PR body 的一行摘要，**不是 pipeline 节点**。自纠错循环细节见 `.claude/commands/ulw.md` §自纠错循环。

## Self-commit（agent 自己提交）

每个落盘产物的 agent **必须**在落盘后、返回 JSON 前执行：

```bash
bash .claude/scripts/agent-commit.sh <agent> <summary>
```

- `<agent>`：本 agent 名（developer 子任务用 `developer-{subtask.id}`，初始如 `developer-2`、retry 如 `developer-retry-1.1`；architect 在 retry 轮仍叫 `architect`，靠 summary 区分初始 vs retry）
- `<summary>`：与返回 JSON 的 `summary` 字段一致

脚本会：
- 根据 agent 名自动推断 pipeline 节点序号（analyst=1 / architect=2 / developer-*=3 / qa=4 / reviewer=5 / security=6 / wiki-curator=7）—— `developer-*` 通配匹配初始 `developer-{i}` 和 retry `developer-retry-{r}.{i}` 两种命名
- `git add -A` + 提交消息 `[ulw] {N}-{agent}: {summary}`
- summary 超 50 字自动截断
- 无 staged 改动 → 静默跳过（idempotent）

commit 后再返回最后一条 JSON 消息。**主会话不 commit**，只在节点 8 push + `gh pr create`。

## 一致性铁律

1. **JSON 返回值与文件 frontmatter 必须逐字段相等**。不一致 = 输出无效。
2. **verdict 必须用枚举值**。禁止自创词。需要表达细节用 `blockers` 数组。
3. **blockers 数组每一项必须是可执行的单句**。例：`"登录处缺 rate-limit"` ✅；`"代码质量整体可以提升"` ❌。
4. **summary 是给用户看的**，主会话汇报时直接复制。
5. **artifact_path 必须与实际落盘路径一致**。
6. **self-commit 是 agent 责任**。落盘 → commit → 返回 JSON 三步缺一不可。

## Agent 之间不直接通信

所有跨 agent 协作经主会话中转。agent 发现需要其他 agent 的产物 → 在 `blockers` 里说明 → 主会话决策。**禁止使用 `SendMessage` 在 teammate 之间直接传 verdict 或 blockers**。

## 通用交付检查（所有 agent 适用）

每个 agent 自家 prompt 只列**专属检查项**；以下通用项由本契约统一管：

- [ ] frontmatter 含全部契约字段（agent / task_slug / verdict / blockers / artifact_path / summary / created_at）
- [ ] verdict 在本 agent 枚举范围内
- [ ] blockers 每项是可执行单句
- [ ] artifact_path 与实际落盘路径一致
- [ ] **已执行 `bash .claude/scripts/agent-commit.sh <agent> "<summary>"`**
- [ ] 最后一条消息是 JSON，与 frontmatter 逐字段相等

## 在 agent prompt 里引用本契约

每个 agent 文件开头加：

```markdown
## 开始前必读

- `docs/templates/agent-contract.md` —— 输入/产物/返回 schema、verdict 枚举、self-commit、通用交付检查
- {agent 专属模板，如 prd.md / design-doc.md / code-review.md}
```

工作流末尾加 §交付检查 列**agent 专属**项即可，通用项无需重复。
