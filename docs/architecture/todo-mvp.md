---
description: apps/todo 模块的包边界、依赖方向、数据模型、关键流程与架构决策
domain: architecture
last_updated_by_spec: todo-mvp-2026-05-21
---

# Todo MVP 架构

## 模块边界

```
apps/todo/
├── package.json              # 名为 `todo`，scripts 接通 turbo
├── tsconfig.json             # strict 模式，ES2020 target
├── vite.config.ts            # @vitejs/plugin-react
├── index.html                # SPA 入口
└── src/
    ├── main.tsx              # ReactDOM.createRoot
    ├── App.tsx               # 调用 useTodos，组合子组件
    ├── types.ts              # Todo 接口 + 常量
    ├── storage.ts            # localStorage 纯函数读写
    ├── useTodos.ts           # 状态 hook（CRUD + 自动持久化）
    ├── styles.css            # 原生 CSS，BEM 命名
    └── components/
        ├── TodoInput.tsx     # 受控文本框 + 提交按钮
        ├── TodoList.tsx      # 遍历 todos 渲染 TodoItem
        ├── TodoItem.tsx      # 单条待办（勾选/编辑/删除）
        └── EmptyState.tsx    # 空列表引导文案
```

## 依赖方向（无环）

```
main → App → useTodos → storage → types
              └── components/* → types
```

- `types.ts` 零依赖，被所有模块引用
- `storage.ts` 仅依赖 `types.ts`
- `useTodos.ts` 依赖 `types.ts` + `storage.ts`
- 组件仅依赖 `types.ts`（通过 props 接收 Todo 数据）
- 无跨模块循环引用

## 数据模型

### Todo 实体

| 字段 | 类型 | 约束 |
|---|---|---|
| `id` | string | `crypto.randomUUID()` 生成，不可变 |
| `text` | string | 1–200 字符，序列化前 trim |
| `completed` | boolean | 默认 `false` |
| `created_at` | ISO 8601 | 创建时生成 |
| `updated_at` | ISO 8601 | edit / toggle 时更新 |

### 持久化

- **存储方式**：localStorage，单一 key `todo-mvp:v1`
- **序列化**：`JSON.stringify(Todo[])` → 整个数组整体写出
- **水合**：`loadTodos()` 在页面加载 / 刷新时读取并校验
- **版本**：key 后缀 `:v1` 预留 future schema 迁移空间（本次未实现迁移逻辑）

### 生命周期

```
new → active(未完成) ⇄ completed(已完成) → deleted（物理删除，无 tombstone）
```

## 关键流程

### 创建待办

```
用户输入 (TodoInput)
  → handleSubmit / handleKeyDown
  → useTodos.add(text)
    → text.trim(), text.slice(0, 200)
    → 构造 Todo { id, text, completed:false, created_at, updated_at }
    → setTodos([newTodo, ...prev])
    → saveTodos(nextTodos)
      → JSON.stringify → localStorage.setItem('todo-mvp:v1', json)
```

### 编辑待办

```
用户双击文本 (TodoItem)
  → setEditing(true)，渲染 <input>
  → 修改后 Enter / blur
  → useTodos.edit(id, text)
    → text.trim() 为空 → no-op（恢复原文）
    → 否则更新 text + updated_at
    → saveTodos(next)
  → Escape → setEditing(false) 不保存
```

### 切换完成状态

```
用户点击 checkbox (TodoItem)
  → onToggle(id)
  → useTodos.toggle(id)
    → map：匹配 id → { ...todo, completed: !todo.completed, updated_at }
    → saveTodos(next)
```

### 删除待办

```
用户点击 ✕ 按钮 (TodoItem)
  → onRemove(id)
  → useTodos.remove(id)
    → filter：排除匹配 id
    → saveTodos(next)
```

## 关键架构决策

### 选型

| 决策 | 选择 | 理由 |
|---|---|---|
| 前端框架 | React 18 + Vite + TypeScript | 团队最主流，生态成熟，与未来测试工具链（Vitest + Testing Library）契合 |
| 持久化 | localStorage | 零后端、零部署、同步 API 简单；MVP 数据量极小（< 100 条） |
| 样式 | 原生 CSS 单文件 | 无额外构建配置；MVP 约 50 行 CSS 足够 |
| 排序 | 创建时间倒序（新的在上） | 最符合"刚添加的最关注"的用户预期 |
| 编辑触发 | 双击文本 | 节省界面空间；有 Esc 取消保障 |
| 空编辑保存 | 拒绝保存，恢复原文 | 避免意外清空数据 |
| P2 功能 | 均不实现 | 保持 MVP 最小范围；筛选/计数/清完成留待后续 |

具体取舍分析见 `docs/specs/todo-mvp-2026-05-21/design.md` §6。

### 安全策略

- 所有用户输入通过 React JSX 文本节点渲染，无 `dangerouslySetInnerHTML`
- 无 `innerHTML`、`document.write`、`eval`
- 存储层 try/catch 吞掉所有异常（quota 满 / 隐私模式 / JSON 解析失败）
- 无网络请求，数据不出浏览器

### 错误处理

| 场景 | 行为 |
|---|---|
| localStorage key 缺失 | `loadTodos()` 返回 `[]` |
| localStorage 数据损坏（JSON 解析失败） | 返回 `[]`（清空） |
| 存储数据 schema 不匹配 | 返回 `[]`（清空）—— 设计取舍：简单优于部分恢复 |
| localStorage quota 满 | `saveTodos()` try/catch 静默吞掉 |
| 隐私模式 / SSR | `loadTodos/saveTodos` 均有 try/catch |
| `crypto.randomUUID()` 在非 secure context 失败 | 无 try/catch（设计已知，要求 localhost 或 HTTPS 运行） |

<!-- HUMAN: start -->
<!-- 留给人手补充：部署拓扑、CI/CD 流程、扩展规划。Wiki Curator 不会修改这里。 -->
<!-- HUMAN: end -->

## Changelog

- 2026-05-21 · spec todo-mvp-2026-05-21 · 初始版本
