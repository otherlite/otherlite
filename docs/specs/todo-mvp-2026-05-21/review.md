---
agent: reviewer
task_slug: todo-mvp-2026-05-21
verdict: pass_with_comments
blockers: []
artifact_path: docs/specs/todo-mvp-2026-05-21/review.md
summary: 代码整洁正确，类型系统完整，UX 边界已覆盖，2 处优化建议
created_at: 2026-05-21T06:50:00Z

type: review
---

# Code Review: Todo MVP

## 检查摘要

- **正确性**：全部 P0/P1 用户故事有对应实现，逻辑链完整，边界处理到位
- **安全**：JSX 文本节点渲染，无 `dangerouslySetInnerHTML`，无 XSS 风险
- **数据持久化**：localStorage 读写均有 try/catch，schema 校验严谨
- **一致性**：BEM 命名、default export、函数风格与项目约定一致
- **可访问性**：全部 input 带 `htmlFor` 关联 label，按钮带 `aria-label`，键盘完整可达
- **简洁**：无多余抽象，无死代码，无调试残留

## 运行验证

| 命令 | 结果 |
|---|---|
| `pnpm -F todo typecheck` | ✅ |
| `pnpm -F todo lint` | ✅ |
| `pnpm -F todo build` | ✅ (34 modules → dist/) |

## 评审意见

### 阻塞（Blocker）

无。

### 应该修（Should Fix）

无。

### 建议（Suggestions）

#### S1. IME 输入法 Enter 提交问题 — `apps/todo/src/components/TodoInput.tsx:17`

`handleKeyDown` 在 `e.key === 'Enter'` 时直接提交，但在中文 / 日文等 IME 输入过程中，Enter 键用于确认当前候选词。此时 `keydown` 事件在部分浏览器触发且 `isComposing` 为 `true`，可能导致**不完整的输入内容被提交**（如输入"牛奶"只提交了"牛"）。

**建议**：用 `<form>` 包裹，改为 `onSubmit` 处理提交。`form` 的 `submit` 事件在 IME 组合期间不会触发，同时自带 Enter 键提交行为，可移除手动 `onKeyDown`。

```tsx
<form className="todo-input-row" onSubmit={(e) => { e.preventDefault(); handleSubmit(); }}>
  <label htmlFor="todo-input" className="sr-only">新待办</label>
  <input id="todo-input" type="text" value={text} onChange={(e) => setText(e.target.value)} placeholder="输入待办事项……" autoFocus />
  <button type="submit" aria-label="添加待办">添加</button>
</form>
```

**严重级别**：建议。对于非 CJX 用户无影响，且有"添加"按钮作为 fallback。

#### S2. `loadTodos` 单条校验失败时全量清空 — `apps/todo/src/storage.ts:28-30`

`isTodo(item)` 校验失败时 `return []` 丢弃**全部**已有数据。若 localStorage 因意外混入一条格式异常的数据，用户会丢失所有待办。

**原因**：design.md 明确要求"读出失败一律返回 []"，当前实现符合设计意图。

**建议**：后续迭代可考虑 `filter` 跳过坏行而非全量清空。当前不修，属设计已知取舍。

## 整体评价

代码质量高。类型系统 100% strict 覆盖，无 `any`，无 `!`（除 `main.tsx` 标准根挂载外），无第三方 UI 库引入。数据流清晰（`useTodos → storage → types` 单向依赖），组件拆分合理。QA 报告风险项均已在设计文档中明确列为已知取舍。

## Changelog

- 2026-05-21：初版（reviewer, autopilot）
