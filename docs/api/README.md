---
description: 对外接口视角的 wiki —— endpoint 群组、协议、契约
domain: meta
---

# docs/api/

每个 markdown 文件描述**一个 API 端点群组**（一个资源 / 一个外部协议），回答 "有哪些接口 / 输入输出 / 错误码 / 鉴权"。

## 写谁

- 后端调用方（前端、其他服务、外部集成方）
- 客户端工程师对照实现

## 维护方

- 主要由 `wiki-curator` 自动更新
- 手写补充必须包在 `<!-- HUMAN: start --> ... <!-- HUMAN: end -->` 保护块内，否则会被 `wiki-curator` 覆盖
- spec frontmatter `affects_docs: [api/xxx]` 指定本次影响的接口

## 文件命名

按资源 / 群组：`{resource}.md`。例如 `users.md`、`billing.md`、`webhooks.md`。

## frontmatter 必填

```yaml
---
description: 一句话接口群描述
domain: api
last_updated_by_spec: {最近一次更新本页的 task-slug}
---
```

## 单个 endpoint 推荐结构

```
## POST /api/users

**鉴权**：JWT (role >= admin)

**请求**
{ "email": string, "name": string }

**响应 200**
{ "id": string, "createdAt": ISO8601 }

**错误**
- 400 ValidationError —— 字段缺失或格式错
- 409 EmailExists —— 邮箱已注册
```
