---
agent: developer-4
task_slug: todo-mvp-2026-05-21
verdict: implementation_complete
blockers: []
artifact_path: docs/specs/todo-mvp-2026-05-21/implementation.md
summary: 实现 UI 组件并组装 App，含受控输入 / 双击编辑 / 勾选删除 / 空态 / 原生 CSS
created_at: 2026-05-21T06:10:00Z

type: implementation
subtask_id: 4
---

## Subtask 1: 创建 todo app 脚手架

- 改动文件：
  - `apps/todo/package.json` —— 名为 `todo`，含 dev/build/lint/typecheck 脚本，依赖 react/react-dom/vite/typescript/@vitejs/plugin-react
  - `apps/todo/tsconfig.json` —— TypeScript 配置，target ES2020、jsx react-jsx、strict 模式，include 指向 src/
  - `apps/todo/vite.config.ts` —— Vite 配置，挂载 @vitejs/plugin-react
  - `apps/todo/index.html` —— HTML 入口，挂载 /src/main.tsx
  - `apps/todo/src/main.tsx` —— React 18 createRoot 入口
  - `apps/todo/src/App.tsx` —— 空壳组件，渲染 `<div />`

- 与 design 的偏差及原因：无

- 跑过的命令与结果：
  - `pnpm install` → pass（4 workspace projects，73 packages added）
  - `pnpm -F todo typecheck` → pass
  - `pnpm -F todo build` → pass（vite v6.4.2，26 modules transformed，输出至 apps/todo/dist）

- 未做但 acceptance 提到的项：无

## Subtask 2: 实现 Todo 类型与 localStorage 存储层

- 改动文件：
  - `apps/todo/src/types.ts` —— 导出 `Todo` 接口（id/text/completed/created_at/updated_at）、`MAX_TEXT_LEN=200` 常量、`STORAGE_KEY='todo-mvp:v1'` 常量
  - `apps/todo/src/storage.ts` —— 导出 `loadTodos(): Todo[]` 与 `saveTodos(todos: Todo[]): void`，使用单一 key `todo-mvp:v1`

- 与 design 的偏差及原因：
  - 在 `types.ts` 额外导出了 `STORAGE_KEY` 常量（design §3 接口契约中写了该值，且 `storage.ts` 需要引用），这不在 acceptance 里明确要求但 design 文档已定，不构成偏差

- 跑过的命令与结果：
  - `pnpm -F todo typecheck` → pass

- 未做但 acceptance 提到的项：无

## Subtask 3: 实现 useTodos 状态 hook

- 改动文件：
  - `apps/todo/src/useTodos.ts` —— 导出 `useTodos()` hook，内部维护 `todos` state（初始值从 `loadTodos()` 水合），暴露 `add` / `toggle` / `edit` / `remove` 四个 action，每个 action 修改 state 后调用 `saveTodos()` 持久化

- 与 design 的偏差及原因：无

- 跑过的命令与结果：
  - `pnpm -F todo typecheck` → pass
  - `pnpm -F todo lint` → pass

- 未做但 acceptance 提到的项：无

## Subtask 4: 实现 UI 组件并组装 App

- 改动文件：
  - `apps/todo/src/components/TodoInput.tsx` —— 受控文本框 + 提交按钮，Enter 或点击按钮触发 onAdd，空白忽略，提交后清空
  - `apps/todo/src/components/TodoItem.tsx` —— checkbox（toggle）+ 文本显示（双击进入编辑模式，blur/Enter 保存，Esc 取消）+ 删除按钮；完成项添加 `data-completed` 属性与删除线样式
  - `apps/todo/src/components/TodoList.tsx` —— 遍历 todos 渲染 TodoItem，列表为空时显示 EmptyState
  - `apps/todo/src/components/EmptyState.tsx` —— 显示「还没有待办，加一条试试」
  - `apps/todo/src/App.tsx` —— 调用 useTodos hook，组合 TodoInput + TodoList
  - `apps/todo/src/main.tsx` —— 引入 `styles.css`
  - `apps/todo/src/styles.css` —— 原生 CSS 样式：sr-only 实用类、布局、输入行、列表、待办项（完成删除线）、编辑态、删除按钮、空态

- 与 design 的偏差及原因：无

- 跑过的命令与结果：
  - `pnpm -F todo typecheck` → pass
  - `pnpm -F todo build` → pass（vite v6.4.2, 34 modules transformed）
  - `pnpm -F todo lint` → pass

- 未做但 acceptance 提到的项：无
