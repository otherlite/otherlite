---
description: 需求已经清晰，agent teams 全流水线跳过 HITL；security/reviewer 结果仍向用户汇报
---

按"无 HITL 自动驾驶"模式处理用户请求：`$ARGUMENTS`

## 调用机制

**agent teams**（TeamCreate）。无 HITL 意味着流水线一路跑到底，并行段（security + reviewer）能充分受益。

## task-slug 生成

同 `/ulw`：自动生成 `{kebab-case-描述}-{YYYY-MM-DD}`，第一句话告知路径。
若参数已是已有 slug → 复用现有产出，从最早缺失的文件开始。

## 流程

启动团队：`TeamCreate(team_name="autopilot-{slug}")`，主会话 = lead。

依次（agent 之间靠文件传递上下文）：

1. **requirements-analyst** → `requirements.md`（**不等用户确认**，直接交给 architect）
2. **architect** → `design.md`；多方案场景**自行选推荐**并在文件里写明"为何选 A 弃 B/C"
3. **developer** → 代码 + `implementation.md`
4. **qa** → `qa-report.md`
5. **security + reviewer** —— **并行** → `security.md` + `review.md`
6. **检查双通过**：
   - reviewer = **通过** 或 **带评论通过**
   - security = **可以合并**
   - 任一未通过 → **跳过步骤 7**，强制中断给用户
7. **wiki-curator** —— 调起 `wiki-curator`，传 `task-slug` 和 `hitl=false`，自动编译 spec 进 docs/features /api /architecture（不等用户确认）
8. 主会话汇总，给用户最终报告（见下方"汇报内容"）

完成或中断：`TeamDelete(team_name="autopilot-{slug}")`。

## 汇报内容（必出，不可简化）

最终给用户一份摘要：

- spec 目录路径：`docs/specs/{slug}/`
- 最终需求摘要（1-3 行）
- 选定的设计方案 + 备选方案被弃原因（如有）
- developer 改动文件清单
- qa 测试结果（通过/失败/跳过）
- **security 完整结论**（Critical/High 全文，Medium/Low 计数）
- **reviewer 完整结论**
- **wiki 改动清单**：修改的 docs/features /api /architecture 文件、新建文件、wiki-curator 报出的不确定项

## 强制中断（即使 autopilot 也要停）

- analyst 发现关键 Open Question 无法从已有上下文回答
- architect 多方案无明显赢家 / 不可逆决策 / 合规相关
- 任何阶段发现破坏性变更（破坏现有 API / 数据丢失 / 不可回滚 migration）
- security 报 **Critical** 或 **High**
- reviewer 给 **要求修改**
- wiki-curator 检测到要写入的内容会**覆盖 HUMAN 保护块**，或现有 wiki 与新内容结构差异巨大

中断时：把当前 spec 目录已有的产出告诉用户，列出需要决策的选项，等用户回复。

## 与 `/ulw` 的区别

| 阶段 | `/ulw` | `/autopilot` |
|---|---|---|
| 调用机制 | agent teams | agent teams |
| analyst HITL | ✅ 等确认 | ❌ 直跑 |
| architect HITL | ✅ 等确认 | ❌ 直跑，多方案 AI 自选 |
| security/reviewer 汇报 | 给用户 | 给用户（不简化） |
| 强制中断点 | 同 autopilot + 关卡 1/2 | 见上方清单 |
