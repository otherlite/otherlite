---
description: 前端实现规则 —— 组件复用、样式方案、无障碍、TS
domain: coding
---

# 前端实现规则

- 复用现有的基础组件（按钮、输入、Modal）再考虑造新的。必须新造的话，简要说明原因。
- 样式跟项目体系一致（Tailwind / CSS modules / styled-components —— 现有哪种用哪种）。不要引入第二套样式方案。
- 无障碍底线：语义化 HTML、input 有 label、键盘可达、focus 可见。不是可选项。
- TypeScript 里不写 `any`（除非有书面理由）。

## 项目特定约定

> 随项目演进填充。当前为空。

- 框架 / 路由 / 状态管理 / 样式方案 / 测试库：（待补充）
- 关键命令（dev server、构建、跑前端测试）：（待补充）
