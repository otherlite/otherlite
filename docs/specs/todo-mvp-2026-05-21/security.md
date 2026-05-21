---
agent: security
task_slug: todo-mvp-2026-05-21
verdict: can_merge
blockers: []
artifact_path: docs/specs/todo-mvp-2026-05-21/security.md
summary: 纯前端 SPA 无后端无网络，XSS 受 React 自动转义保护，依赖均为行业标准，无 Critical/High
created_at: 2026-05-21T07:10:00Z

type: security
severity_breakdown: {critical: 0, high: 0, medium: 0, low: 2}
---

# Security Review: Todo MVP

## Review Scope

- **应用类型**: 纯前端 SPA，React 18 + Vite + TypeScript
- **数据持久化**: localStorage（单 key `todo-mvp:v1`）
- **后端**: 无
- **网络请求**: 零（无 fetch / XHR / WebSocket）
- **认证**: 无（单用户本地应用，需求明确 Out of Scope）

## 攻击面概述

| 攻击面 | 状态 | 说明 |
|--------|------|------|
| XSS（反射/存储） | ✅ 安全 | 全部通过 React JSX 文本节点渲染，无 `dangerouslySetInnerHTML` |
| DOM 注入 | ✅ 安全 | 无 `innerHTML`、`document.write`、`eval` |
| 命令注入 | ✅ 不适用 | 无后端进程、无 shell 调用 |
| SQL/NoSQL 注入 | ✅ 不适用 | 无数据库 |
| 路径穿越 | ✅ 不适用 | 无文件系统操作（localStorage 浏览器沙箱隔离） |
| SSRF | ✅ 不适用 | 无出站网络请求 |
| 反序列化攻击 | ✅ 安全 | `JSON.parse` 标准解析，无原型污染风险 |
| 认证绕过 | ✅ 不适用 | 无认证机制 |
| 密钥泄露 | ✅ 不适用 | 无密钥/Token/密码 |
| 数据泄漏（网络） | ✅ 不适用 | 无网络请求，数据不出浏览器 |
| 供应链攻击 | ✅ 安全 | 依赖均为行业标准库，已提交 lockfile |
| CSP 等安全头 | ⚠️ 基建层 | Vite dev server 未配置 CSP，属基建层职责，非本次范围 |

## 用户可控数据追踪

```
用户输入 (TodoInput text)
  → useTodos.add(text)
    → text.trim() + text.slice(0, MAX_TEXT_LEN)
    → Todo 对象 → JSON.stringify → localStorage.setItem
  → loadTodos()
    → localStorage.getItem → JSON.parse → isTodo() schema 校验
    → TodoItem JSX 渲染
      → <span>{todo.text}</span>        ← React 自动转义 ✅
      → aria-label={`删除「${todo.text}」`}  ← React 自动转义 ✅
      → data-completed={boolean}        ← 布尔值，安全 ✅
```

## 危险模式 grep 结果

| 关键词 | 结果 |
|--------|------|
| `dangerouslySetInnerHTML` | 未命中 |
| `innerHTML` | 未命中（仅 `inner` 无关联） |
| `eval` | 未命中 |
| `exec` | 未命中 |
| `child_process` | 未命中（前端代码） |
| `Math.random` | 未命中 |
| `process.env` | 未命中 |
| `raw` | 仅 `storage.ts` 中 `const raw = ...`，安全 |
| `MD5` / `SHA1` / `alg.*none` | 未命中 |
| `pickle.load` / `yaml.load` | 未命中（非 Python） |

## 发现

### Low

#### L1. `crypto.randomUUID()` 无 try/catch 保护

- **文件**: `apps/todo/src/useTodos.ts:15`
- **影响**: 在非安全上下文（HTTP 而非 HTTPS/本地）中，`crypto.randomUUID()` 抛出 `SecurityError`，异常传播至 React 事件处理，添加操作静默失败（用户无法创建新待办）。无敏感数据泄漏风险。
- **复现**: 将应用部署至纯 HTTP 生产环境（非 localhost），用户点击"添加" → 控制台报错，UI 不更新。
- **修复建议**: 在 `add()` 内包裹 try/catch 或添加回退方案（如 `Date.now().toString(36) + Math.random().toString(36).slice(2)`），配合日志上报。
- **已记录**: 设计文档 §8 风险矩阵已列此项为已知风险，指定 localhost 或 HTTPS 为运行前提。当前不对 MVP 构成阻塞。
- **严重级别**: Low

#### L2. localStorage 单条 schema 校验失败时全量清空

- **文件**: `apps/todo/src/storage.ts:28-30`
- **影响**: 若 localStorage 因任何原因混入一条格式异常的数据（如其他应用写入了同一 key、浏览器扩展干扰），`loadTodos()` 执行 `return []` 丢弃全部已有数据。用户丢失所有待办。
- **复现**: 在浏览器 DevTools 中手动向 `localStorage['todo-mvp:v1']` 写入一条格式错误的 JSON（如 `[{"id":"1","text":"test"}]` 缺字段），刷新页面 → 列表清空。
- **修复建议**: 将 `return []` 改为 `continue`（跳过坏行），或使用 `.filter(isTodo)`。
- **已记录**: review.md §S2 和 qa-report.md 均已标注此为设计已知取舍；design.md 明确要求"读出失败一律返回 []"。
- **严重级别**: Low

## 未发现的问题（确认清单）

- XSS: 零 `dangerouslySetInnerHTML`，零 `innerHTML` 拼接，aria-label 使用模板字符串但 React 自动转义 ✅
- 依赖供应链: `react`/`react-dom`/`vite`/`typescript`/`@vitejs/plugin-react` 均为行业标准，无 typo-squat 风险 ✅
- Lockfile: `pnpm-lock.yaml` 已提交（1224 行） ✅
- 错误信息泄漏: 所有存储操作 try/catch 静默处理，不暴露路径/堆栈 ✅
- 数据不出本机: 零网络请求，无第三方 SDK ✅
- 输入长度限制: `add()` 截断至 200 字符 ✅
- 空白输入拒绝: `add()` 和 `edit()` 均做 `trim()` 后空则 no-op ✅

## Changelog

- 2026-05-21：初版（security, autopilot）
