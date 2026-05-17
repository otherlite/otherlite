---
description: 小范围 bug 修复 / typo / 配置改 —— subagent 直跑 developer → reviewer，不落 specs
---

按"最小路径"模式处理用户请求：`$ARGUMENTS`

## 调用机制

**subagent**（通过 Agent 工具调起，不用 TeamCreate）。

## 不生成 task-slug

小修复不落 `docs/specs/`，因为创建一坨文件夹的开销 > 修一个 typo 的收益。所有 agent prompt 里**不要**传 `task-slug` —— 让 agent 的"产出落盘"逻辑被跳过。

## 流程

1. 调起 `developer` agent 实现修复。prompt 模板：
   > 任务：{用户原始请求}
   > 不传 task-slug。直接改代码 + 跑相关测试 + 返回改动文件清单。

2. developer 返回后，调起 `reviewer` agent 做合并前审查。prompt 模板：
   > 审查刚才 developer 的改动（diff 见 `git diff`）。不传 task-slug，结论直接返回。

3. **触发条件下额外调起 `security`**：改动触及鉴权 / 密钥 / 加密 / 用户输入流向 DB/shell/fs / 对外端点 → 并行（与 reviewer 同一条消息发出）。

4. 汇总 reviewer（+ security）结论 → 给用户。

## 适用边界

发现以下情况，**停下来反问用户**是否切到 `/ulw` 或 `/autopilot`：

- 跨多个模块、需要新数据模型 / 新接口
- 用户描述本身模糊
- 需要新增依赖或破坏现有契约

## HITL

- developer 完成后不等用户确认，直接进 reviewer。
- reviewer 给出"要求修改" → 把详情交给用户决定，**不自动迭代**。
