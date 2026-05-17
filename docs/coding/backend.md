---
description: 后端实现规则 —— 防御性代码边界、migration、日志
domain: coding
---

# 后端实现规则

- 不为不可能发生的情况写防御性代码。信任内部调用方；只在系统边界做校验（HTTP handler、队列消费者、外部 API 响应）。
- Migration：能可逆就写成可逆的；不行就在 migration 文件或 PR 描述里明说。
- 不要把 `console.log` / `print` 调试代码留在里面，用项目的 logger。

## 项目特定约定

> 随项目演进填充。当前为空。

- 运行时 / 框架 / ORM / DB / 队列 / 缓存：（待补充）
- 错误处理范式（Result/Either / throw / 错误码）：（待补充）
- 日志规范（logger 实例、级别约定、结构化字段）：（待补充）
- 环境变量管理（如何加新变量、本地/CI/prod 差异）：（待补充）
- 常用命令（启动 dev、跑测试、跑 lint、构建）：（待补充）
