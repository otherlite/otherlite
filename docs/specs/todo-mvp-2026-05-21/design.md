---
agent: architect
task_slug: todo-mvp-2026-05-21
verdict: ready_for_impl
blockers: []
artifact_path: docs/specs/todo-mvp-2026-05-21/design.md
summary: React+Vite+TS 单页应用，localStorage 持久化，无后端无路由，拆 4 个 developer 子任务
created_at: 2026-05-21T00:30:00Z

type: design
affects_docs: [features/todo-mvp, architecture/todo-mvp]
status: draft
subtasks:
  - id: 1
    title: 创建 todo app 脚手架
    files:
      - apps/todo/package.json
      - apps/todo/tsconfig.json
      - apps/todo/vite.config.ts
      - apps/todo/index.html
      - apps/todo/src/main.tsx
      - apps/todo/src/App.tsx
    summary: React+Vite+TS 脚手架，dev/build/lint/typecheck 脚本接通 turbo
    acceptance: |
      - `apps/todo/package.json` 名为 `todo`，scripts 含 `dev`/`build`/`lint`/`typecheck`
      - 仓库根 `pnpm install` 不报错
      - 仓库根 `pnpm -F todo typecheck` 通过（App.tsx 渲染空壳即可）
      - 仓库根 `pnpm -F todo build` 产物输出至 `apps/todo/dist`
      - 引入 react / react-dom / typescript / vite / @vitejs/plugin-react 作为依赖；不引第三方 UI 库或 Tailwind
  - id: 2
    title: 实现 Todo 类型与 localStorage 存储层
    files:
      - apps/todo/src/types.ts
      - apps/todo/src/storage.ts
    summary: Todo 实体类型 + 读写 localStorage 的纯函数模块
    acceptance: |
      - `types.ts` 导出 `Todo` 接口（id/text/completed/created_at/updated_at）与 `MAX_TEXT_LEN=200` 常量
      - `storage.ts` 导出 `loadTodos(): Todo[]`、`saveTodos(todos: Todo[]): void`，使用单一 key `todo-mvp:v1`
      - `loadTodos` 在数据缺失 / JSON 解析失败 / schema 不匹配时返回 `[]`，不抛异常
      - `saveTodos` 在 `localStorage` 不可用（quota / SSR）时 try/catch 静默，不抛异常
      - 顶层 `pnpm -F todo typecheck` 通过
  - id: 3
    title: 实现 useTodos 状态 hook
    files:
      - apps/todo/src/useTodos.ts
    summary: 暴露 todos 数组与 add/toggle/edit/remove 四个 action，内部自动持久化
    acceptance: |
      - 导出 `useTodos()` 返回 `{ todos, add, toggle, edit, remove }`
      - 初始 state 来自 `loadTodos()`
      - 任一 action 触发后调用 `saveTodos(next)`
      - `add(text)`：trim 后为空字符串拒绝；超过 `MAX_TEXT_LEN` 截断；id 用 `crypto.randomUUID()`；新项追加到列表头部
      - `edit(id, text)`：trim 为空则不更新（沿用旧 text）；更新 `updated_at`
      - `toggle(id)` / `remove(id)`：按 id 精确匹配
      - 顶层 `pnpm -F todo typecheck` 通过
  - id: 4
    title: 实现 UI 组件并组装 App
    files:
      - apps/todo/src/App.tsx
      - apps/todo/src/components/TodoInput.tsx
      - apps/todo/src/components/TodoList.tsx
      - apps/todo/src/components/TodoItem.tsx
      - apps/todo/src/components/EmptyState.tsx
      - apps/todo/src/styles.css
      - apps/todo/src/main.tsx
    summary: 输入框 + 列表 + 单项（勾选/编辑/删除）+ 空态 + 原生 CSS
    acceptance: |
      - `TodoInput`：受控文本框 + 提交按钮，回车或点按钮触发 `onAdd(text)`，空白文本静默忽略，提交后清空
      - `TodoItem`：checkbox（toggle）+ 文本（双击进入编辑模式，blur 或回车保存，Esc 取消）+ 删除按钮；完成项加 `data-completed` 属性 + 删除线样式
      - `TodoList`：把 todos map 成 `TodoItem`；列表为空时渲染 `EmptyState`
      - `EmptyState`：显示「还没有待办，加一条试试」
      - `App`：调用 `useTodos`，组合上述组件
      - `main.tsx` 引入 `styles.css`
      - 所有 input 有关联 `<label>`（可视隐藏可），按钮有 `aria-label`，键盘 Tab/Enter/Space 完成全部 P0 操作
      - 渲染 todo 文本始终走 React JSX 文本节点，不出现 `dangerouslySetInnerHTML`
      - 顶层 `pnpm -F todo typecheck` 通过、`pnpm -F todo build` 通过
retry_rounds: []
---

# Todo MVP Web —— 设计文档

## 1. 摘要

把 `apps/todo/` 实现成一个 **React 18 + Vite + TypeScript 单页应用**，状态完全在浏览器 `localStorage`，无后端、无路由、无状态管理库。所有 Todo 操作（CRUD + toggle）在内存中改完后整体序列化回 `localStorage`，刷新页面后 `useTodos` hook 重新水合。组件层用原生 CSS（同一文件），不引入 Tailwind / styled-components 等第二套样式方案。

## 2. 假设

依据 `requirements.md` §10 Open Questions：

| 假设 | 来源 | 选择 |
|---|---|---|
| 持久化 | OQ-1 | localStorage（默认） |
| 前端框架 | OQ-2 | React 18 + Vite |
| 样式 | OQ-3 | 原生 CSS（单文件） |
| 排序 | OQ-4 | 创建时间倒序（新的在上）|
| 编辑触发 | OQ-5 | 双击文本进入编辑态 |
| 编辑保存空文本 | OQ-6 | 拒绝保存，恢复原文 |
| P2 功能（筛选/计数/清完成） | OQ-7 | 不实现（MVP 心态，留给后续）|

外部决策需求：无。所有假设落到取舍分析与组件契约里。

## 3. 接口契约

**纯前端，无 HTTP API。**模块内部接口如下。

### `types.ts`

```ts
export interface Todo {
  id: string;            // crypto.randomUUID()
  text: string;          // 1..MAX_TEXT_LEN 字符
  completed: boolean;
  created_at: string;    // ISO 8601
  updated_at: string;    // ISO 8601
}

export const MAX_TEXT_LEN = 200;
export const STORAGE_KEY = 'todo-mvp:v1';
```

### `storage.ts`

```ts
export function loadTodos(): Todo[];
export function saveTodos(todos: Todo[]): void;
```

读出失败（缺失 / JSON 解析失败 / 字段不全）一律返回 `[]`；写入失败（quota / SSR / 隐私模式）try/catch 吞掉，不抛出。

### `useTodos.ts`

```ts
export function useTodos(): {
  todos: Todo[];
  add(text: string): void;
  toggle(id: string): void;
  edit(id: string, text: string): void;
  remove(id: string): void;
};
```

行为约束：
- `add`：`text.trim()` 后为空 → no-op；长度 > `MAX_TEXT_LEN` → 截断；新 todo 追加到数组头部
- `edit`：`text.trim()` 后为空 → no-op；否则更新 `text` + `updated_at`
- 任何状态修改后立刻 `saveTodos(next)`

### 组件 props 契约

```ts
TodoInput  : { onAdd: (text: string) => void }
TodoList   : { todos: Todo[]; onToggle, onEdit, onRemove }
TodoItem   : { todo: Todo; onToggle, onEdit, onRemove }
EmptyState : { /* 无 props */ }
```

## 4. 数据模型

**单一 localStorage key `todo-mvp:v1`**，值为 `Todo[]` 的 JSON 序列化。版本号后缀（`:v1`）预留未来 schema 升级的迁移空间，本次不实现迁移逻辑。

| 字段 | 类型 | 约束 |
|---|---|---|
| `id` | string | `crypto.randomUUID()` 生成；不可变 |
| `text` | string | 1–200 字符；序列化前 trim |
| `completed` | boolean | 默认 `false` |
| `created_at` | ISO 8601 | 创建时由前端生成 |
| `updated_at` | ISO 8601 | `edit` / `toggle` 时更新 |

无索引、无关系、无外键 —— 单数组扫表。100 条规模下 O(n) 更新远低于 100ms 性能预算。

## 5. 组件边界

```
apps/todo/
├── package.json          # 名为 `todo`，scripts 接通 turbo
├── tsconfig.json
├── vite.config.ts
├── index.html
└── src/
    ├── main.tsx          # ReactDOM.createRoot，引 styles.css
    ├── App.tsx           # 调 useTodos，组合子组件
    ├── types.ts          # Todo 类型 + 常量
    ├── storage.ts        # localStorage 纯函数
    ├── useTodos.ts       # 状态 hook
    ├── styles.css        # 原生 CSS
    └── components/
        ├── TodoInput.tsx
        ├── TodoList.tsx
        ├── TodoItem.tsx
        └── EmptyState.tsx
```

依赖方向（无环）：
```
main → App → useTodos → storage → types
              └── components/* → types
```

## 6. 取舍分析

### 持久化方案

#### 方案 A：localStorage（推荐）
- 优点：零后端、零部署、零迁移；同步 API 简单；满足 requirements §3 持久化
- 缺点：单浏览器、约 5MB 上限、quota 满了写入失败需 catch
- 成本：实现 ~半天 / 运维零 / 学习零

#### 方案 B：Next.js + SQLite（better-sqlite3）
- 优点：未来扩展容易；数据更"正式"
- 缺点：要起后端进程、要管 db 文件位置、要写迁移；MVP 阶段纯负担
- 成本：实现 1–2 天 / 运维需考虑 db 备份 / 学习有 ORM 选型成本

#### 方案 C：纯前端 + IndexedDB
- 优点：容量更大、能存 blob
- 缺点：API 更繁、需要 wrapper（idb 等）；MVP 数据量极小，收益为零
- 成本：实现 半–1 天 / 运维零 / 学习需熟悉 IDB

#### 推荐
**方案 A**，理由：MVP 数据规模极小（100 条以内），单浏览器、单用户、无同步是 requirements 明确 Out of Scope 的事项。localStorage 同步 API 让 `useTodos` 实现可读性最高，避免 async/await 污染 hook。

### 前端框架

#### 方案 A：React 18 + Vite（推荐）
- 优点：团队/社区最广，TS 模板成熟；Vite dev server 极快
- 缺点：bundle 比 Svelte 大几 KB（MVP 不在意）
- 成本：实现/学习/运维都低

#### 方案 B：Svelte 4 + Vite
- 优点：bundle 最小，代码最简
- 缺点：团队熟练度未知；项目首个 frontend，挑保守选项
- 成本：实现略低 / 学习高于 React / 运维零

#### 方案 C：纯 HTML + Vanilla TS
- 优点：依赖最少
- 缺点：手动管 DOM 与 state 同步；TS 类型推不到 DOM 节点的"业务字段"；可维护性最差
- 成本：实现 / 运维都最高

#### 推荐
**方案 A**，理由："最保守"原则下选最主流方案；与未来若加测试（Vitest + Testing Library）的生态最契合。

### 样式方案

**原生 CSS 单文件**（不写取舍分析详格式 —— 这不是真有 2 个方案）：Tailwind 要配 PostCSS / content scan，CSS-in-JS 要额外 runtime；MVP 一个 `styles.css` ~50 行能搞定。

## 7. 迁移路径

**全新代码，无在途工作要兼容。**`apps/english/` 与 `apps/texas/` 都是空壳 `package.json`，互不影响。

新增 `apps/todo/` 会被 `pnpm-workspace.yaml` 自动纳入（已有 `apps/*` 通配）。`turbo.json` 已有 `build`/`lint`/`dev` 任务定义，新 app 的 scripts 命名一致即可被识别。

## 8. 风险与回滚

| 风险 | 影响 | 应对 |
|---|---|---|
| `localStorage` 在隐私模式 / quota 满时写入抛错 | 用户操作"看起来生效"但刷新后丢失 | `saveTodos` try/catch；不阻塞 UI；MVP 不显式提示（Out of Scope）|
| `crypto.randomUUID()` 在非 https / 旧浏览器不可用 | 创建 todo 抛错 | requirements §7 限定"最新两个主版本"浏览器，`randomUUID` 全支持；本地 dev 走 `localhost` 也算 secure context |
| 双击编辑误触 | 用户体验不佳 | 双击同时支持显式按钮：MVP 阶段双击足够，必要时后续加按钮 |
| `data-completed` 选择器与未来 CSS 冲突 | 视觉错乱 | 类名加 `todo-` 前缀做命名空间 |

**回滚**：本次改动局限在 `apps/todo/`，删目录即回滚。无 db migration、无 lockfile 强绑定（除 react/vite/typescript 这些通用库）。

## 9. Open Questions

无。requirements §10 所有 Open Questions 已在本设计中假设落地（§2）。

## 10. Changelog

- 2026-05-21 · 初版（architect, autopilot）· 选 React+Vite+TS+localStorage，拆 4 个 developer subtask
