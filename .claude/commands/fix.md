---
description: 小范围 bug 修复 / typo / 配置改 —— subagent 直跑 developer → reviewer，不落 specs
---

按"最小路径"模式处理用户请求：`$ARGUMENTS`

## 调用机制

**subagent**（通过 Agent 工具调起，不用 TeamCreate）。

## 不生成 task-slug

小修复不落 `docs/specs/`。所有 agent 输入消息里 `task_slug = null` / `outputs_required = []`（见 `docs/templates/agent-contract.md` "无 slug 场景"）。agent 不落产物文件，只返回 JSON。

## Pipeline

主会话按以下节点调度。agent 输入/输出遵循 `docs/templates/agent-contract.md` 的"无 slug 场景"规则。

1. **developer** → 代码改动
   - 输入：`{task_slug: null, inputs: [], outputs_required: [], iteration: 0, previous_feedback: null}` + 用户原始请求
   - 直接改代码 + 跑相关测试
   - verdict = `implementation_complete`

2. **reviewer** [deps: 1] + **security**（触发条件时与 reviewer 并行 `‖`） → JSON 结论
   - reviewer 总是调起
   - security 触发条件：改动触及鉴权 / 密钥 / 加密 / 用户输入流向 DB·shell·fs / 对外端点
   - 触发时一条消息里同时 Agent 两个；都仅返回 JSON（无 slug 不落文件）

3. **gate** [deps: 2]
   - 通过条件: `reviewer.verdict ∈ {pass, pass_with_comments}` AND（如有 security）`security.verdict = can_merge`
   - 否则: halt to user，给出 blockers（迭代策略见下方 HITL 段）

4. **lead 汇报** [deps: 3]
   - reviewer.summary + （如有）security.summary 给用户
   - gate fail → 让用户决定下一步（修 / 不修 / 升级到 `/ulw`）

## 适用边界

发现以下情况，**停下来反问用户**是否切到 `/ulw`：

- 跨多个模块、需要新数据模型 / 新接口
- 用户描述本身模糊
- 需要新增依赖或破坏现有契约
- developer 返回的 blockers 表明任务范围超预期

## HITL

- developer 完成后不等用户确认，直接进 reviewer
- gate fail → 把 blockers 详情交给用户决定，**不自动迭代**
