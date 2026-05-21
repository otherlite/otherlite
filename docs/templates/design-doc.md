---
description: 设计文档模板 —— 段落顺序、取舍分析强制格式
domain: templates
---

# 设计文档模板

## 标准段落顺序

1. 摘要（一段话）
2. 假设（基于 requirements.md 哪些点，缺什么需要外部决策）
3. 接口契约（API 端点 method/path/req/res；函数签名；事件 payload）
4. 数据模型（schema 变更、新表、索引、约束）
5. 组件边界（谁拥有什么、模块间通信）
6. 取舍分析（如有多方案：每个选项 pros/cons + 推荐）
7. 迁移路径（如何从当前状态到目标状态而不打断在途工作）
8. 风险与回滚
9. Open Questions
10. Changelog

## Frontmatter `subtasks` 字段（架构师必填）

实施工作必须在 frontmatter 拆成 `subtasks` 列表（至少 1 项），驱动 `/ulw` 节点 3 的 developer 循环：

```yaml
subtasks:
  - id: 1                            # int，从 1 起严格递增
    title: 创建 Foo 数据模型           # ≤ 30 字
    files: [src/models/foo.ts]       # 将要新建 / 修改的文件
    summary: 定义 Foo 类型与 zod schema # ≤ 50 字
    acceptance: |                    # 客观完成判断
      - typecheck 通过
      - 导出 Foo 类型与 fooSchema
  - id: 2
    title: 添加 Foo POST API
    files: [src/api/foo.ts, src/routes.ts]
    summary: 实现 POST /foo 路由
    acceptance: |
      - 请求体走 fooSchema 校验
      - 鉴权中间件挂上
      - 返回 201 + 新建对象
```

拆分原则（详见 `.claude/agents/architect.md` "子任务拆分"段）：
- **小**：1-3 个文件
- **独立**：每个 subtask 完成后整个仓库可单独通过 typecheck
- **有序**：id 严格递增；A 提供 B 依赖的类型 → A.id < B.id
- **覆盖**：design 提及的所有实施工作都有对应 subtask
- **不重叠**：两个 subtask 不写同一文件的同一段

## Frontmatter `retry_rounds` 字段（自纠错循环填）

`/ulw` 节点 4-6 任一异常 → architect 被以 `retry_round: N` 重新调起，append 一项到 `retry_rounds`，给 developer 跑新一轮修复 subtasks。两 mode 共用（HITL 用户三选触发，autopilot 自动触发）。初始落盘为 `[]`。

```yaml
retry_rounds:
  - round: 1                         # int，从 1 严格递增
    trigger:                         # 触发本轮 retry 的三个 check verdict 快照
      qa: fail                       # fail | pass
      reviewer: request_changes      # pass | pass_with_comments | request_changes
      security: can_merge            # can_merge | cannot_merge
    subtasks:
      - id: retry-1.1                # 字符串 retry-{round}.{index}，index 从 1 起
        title: 修复 POST /foo 鉴权未挂
        files: [src/api/foo.ts]
        summary: 加 requireAuth 中间件
        acceptance: |
          - security.md "鉴权缺失" blocker 关闭
          - 现有 fooSchema 校验保留
```

- 每轮 retry 只 append 不修改既有项；`subtasks`（初始那批）保持不动
- 主体顶部 Changelog 加一条 `{date} · round-{N} retry planning`
- 详见 `.claude/agents/architect.md` "Retry 模式"段与 `.claude/commands/ulw.md` §自纠错循环

## 取舍分析格式

多方案时强制用此格式：

```
### 方案 A：{名称}
- 优点：...
- 缺点：...
- 成本：实现 / 运维 / 学习

### 方案 B：{名称}
（同上）

### 推荐
方案 A，理由：...
```

## 项目特定约定

> 随项目演进填充。当前为空。

- **包边界**（monorepo，apps/ 与 packages/ 的划分原则）：（待补充）
- **API 契约风格**（REST / GraphQL / RPC / 命名约定 / 错误码风格）：（待补充）
- **数据访问层范式**（仓储模式 / 直接 ORM / DAO）：（待补充）
- **跨服务通信**（HTTP / 队列 / 事件总线）：（待补充）
- **优先选用的库**（已选定的默认库，避免重复选型）：（待补充）
- **明确禁用的方案**（历史踩坑、合规禁止）：（待补充）
- **ADR 归档位置**：`docs/architecture/adr/`
