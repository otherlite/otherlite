---
agent: developer-1
task_slug: todo-mvp-2026-05-21
verdict: implementation_complete
blockers: []
artifact_path: docs/specs/todo-mvp-2026-05-21/implementation.md
summary: React+Vite+TS 脚手架，dev/build/lint/typecheck 脚本接通 turbo
created_at: 2026-05-21T00:30:00Z

type: implementation
subtask_id: 1
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
