---
description: agent 交付契约 —— 产物 frontmatter / 返回消息 / 输入消息的 schema，verdict 枚举，一致性铁律
domain: templates
---

# Agent 交付契约

所有 agent 与主会话（team lead）之间的通信遵循本契约。目的：让 gate 判定、HITL 中断、迭代触发**靠结构化字段**，不靠 LLM 解析自然语言。

## 三种 schema

### 1. 产物文件 frontmatter（单一事实源）

每个 agent 落盘的产物（`docs/specs/{slug}/*.md`）**必须**带以下 frontmatter：

```yaml
---
agent: reviewer                          # agent 名（见下方枚举）
task_slug: tiered-pricing-2026-05-17     # 任务 slug
verdict: pass_with_comments              # 该 agent 的判定（枚举见下方）
blockers: []                             # 阻塞下游的事项数组，无则空数组
needs_iteration: false                   # 是否要求上游 agent 二次迭代
artifact_path: docs/specs/tiered-pricing-2026-05-17/review.md  # 本文件相对仓库根的路径
summary: 代码质量整体好，3 处可读性改进建议   # 一句话摘要（≤ 80 字）
created_at: 2026-05-20T10:30:00Z         # ISO 8601
iteration: 0                             # 本次是第几轮迭代（首次=0）
---
```

字段语义：

| 字段 | 类型 | 是否必填 | 说明 |
|---|---|---|---|
| `agent` | string | ✅ | 见下方 agent 枚举 |
| `task_slug` | string | ✅ | 来自主会话输入 |
| `verdict` | enum | ✅ | 按 agent 不同，枚举不同（见下方） |
| `blockers` | string[] | ✅（无则 `[]`） | 阻塞下游的条目。`verdict` 表示态度，`blockers` 给细节 |
| `needs_iteration` | bool | ✅ | true 时主会话会触发上游迭代（仅 reviewer/security 可置 true） |
| `artifact_path` | string | ✅ | 仓库相对路径，方便机器跳转 |
| `summary` | string | ✅ | ≤ 80 字，给主会话向用户汇报用 |
| `created_at` | ISO 8601 | ✅ | 落盘时间 |
| `iteration` | int | ✅ | 0-based 迭代轮次 |

主体（frontmatter 之后的 markdown）按各 agent 自己的 template 约束（`prd.md`、`design-doc.md`、`code-review.md` 等）。

**扩展字段**：除上表 9 个契约字段外，agent 可加自家业务字段（如 `type` / `affects_docs` / `status` / `last_updated_by_spec`），下游消费者按需读取。约束：

- 不可与契约字段同名
- 不可改契约字段语义（例如不能让 `verdict` 字段套别的值域）
- 加新业务字段前先想清楚谁会消费，不消费的不要加

下表是各 agent 已在用的业务字段，新增时先复用：

| Agent | 业务字段 | 消费方 |
|---|---|---|
| analyst | `type: requirements` · `affects_docs[]` · `status: draft\|approved` | wiki-curator |
| architect | `type: design` · `affects_docs[]` · `status: draft\|approved` | wiki-curator |
| developer | `type: implementation` | — |
| qa | `type: qa-report` | — |
| reviewer | `type: review` | 主会话（gate 用 `verdict`） |
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
  "needs_iteration": false,
  "artifact_path": "docs/specs/tiered-pricing-2026-05-17/review.md",
  "summary": "代码质量整体好，3 处可读性改进建议",
  "iteration": 0
}
```

**铁律**：JSON 字段值必须与落盘 frontmatter **逐字段相等**。两者不一致 → agent 输出无效，主会话拒收，要求重做。

### 3. 主会话给 agent 的输入消息

主会话调起 agent 时（`Agent({...})` 的 prompt 部分）前置一段 JSON：

```json
{
  "task_slug": "tiered-pricing-2026-05-17",
  "inputs": [
    "docs/specs/tiered-pricing-2026-05-17/requirements.md",
    "docs/specs/tiered-pricing-2026-05-17/design.md"
  ],
  "outputs_required": ["docs/specs/tiered-pricing-2026-05-17/review.md"],
  "iteration": 0,
  "previous_feedback": null
}
```

迭代时（`iteration > 0`）`previous_feedback` 填上一次的 blockers 数组：

```json
{
  "task_slug": "...",
  "inputs": [...],
  "outputs_required": [...],
  "iteration": 1,
  "previous_feedback": {
    "from": "reviewer",
    "blockers": ["登录处缺 rate-limit", "SQL 拼接未参数化"]
  }
}
```

输入消息字段语义：

| 字段 | 类型 | 说明 |
|---|---|---|
| `task_slug` | string | 任务标识 |
| `inputs` | string[] | agent **必读**的文件路径清单 |
| `outputs_required` | string[] | agent **必须落盘**的文件路径清单 |
| `iteration` | int | 本次迭代轮次 |
| `previous_feedback` | object \| null | 仅迭代时填，含 `from` 和 `blockers` |

## Agent 枚举与 verdict 枚举

| agent | verdict 枚举 | 何时 needs_iteration 可为 true |
|---|---|---|
| `analyst` | `ready_for_design` / `needs_more_info` | 不允许（用 verdict 表态即可） |
| `architect` | `ready_for_impl` / `needs_user_decision` | 不允许 |
| `developer` | `implementation_complete` | 不允许（developer 是被迭代方，不发起迭代） |
| `qa` | `pass` / `fail` | `fail` 时可为 true |
| `reviewer` | `pass` / `pass_with_comments` / `request_changes` | `request_changes` 时**必须**为 true |
| `security` | `can_merge` / `cannot_merge` | `cannot_merge` 时**必须**为 true |
| `wiki-curator` | `ready_to_apply` / `needs_human_review` | 不允许 |

新增 verdict 值需要先改本文件 + 同步改对应 agent prompt，禁止 agent 私自创造枚举值。

## Gate 判定

主会话基于 verdict 字段判定，**不读产物主体**：

```
gate.pass ⇔
  reviewer.verdict ∈ {pass, pass_with_comments}
  AND security.verdict == can_merge
```

任一不满足 → halt to user（呈现 blockers，等用户决定是否触发 developer 迭代）。

## 一致性铁律

1. **JSON 返回值与文件 frontmatter 必须逐字段相等**。不一致 = 输出无效。
2. **verdict 必须用枚举值**。禁止自创词（如 `mostly_pass`、`approved_with_caveats`）。需要表达细节用 `blockers` 数组。
3. **needs_iteration 只能由 reviewer / security / qa 置 true**。其他 agent 强制为 false。
4. **blockers 数组每一项必须是可执行的单句**（不是段落、不是建议、不是赞美）。例：`"登录处缺 rate-limit"` ✅；`"代码质量整体可以提升"` ❌。
5. **summary 是给用户看的**，主会话汇报时直接复制，不二次翻译。
6. **iteration 字段由主会话注入**，agent 不自行决定。
7. **artifact_path 必须与实际落盘路径一致**。Agent 落盘后自检。

## Agent 之间不直接通信

所有跨 agent 协作经主会话中转。agent 发现需要其他 agent 的产物 → 在 `blockers` 里说明 → 主会话决策。**禁止使用 `SendMessage` 在 teammate 之间直接传 verdict 或 blockers**（HITL 哲学要求用户可见所有关键决策）。

## 在 agent prompt 里引用本契约

每个 agent 的 prompt（`.claude/agents/{name}.md`）开始处加一段：

```markdown
## 开始前必读

- `docs/templates/agent-contract.md` —— 输入/产物/返回消息的 schema，verdict 枚举，一致性铁律
- {该 agent 专属的产物模板，如 prd.md / design-doc.md / code-review.md}
```

并在工作流末尾加"交付检查"小节：

```markdown
## 交付检查

落盘前自检：
- [ ] frontmatter 字段齐全（agent / task_slug / verdict / blockers / needs_iteration / artifact_path / summary / created_at / iteration）
- [ ] verdict 在本 agent 枚举范围内
- [ ] blockers 每项是可执行单句
- [ ] artifact_path 与实际落盘路径一致
- [ ] 最后一条消息是 JSON，字段与 frontmatter 逐字段相等
```

## Changelog

- 2026-05-20：初版。
