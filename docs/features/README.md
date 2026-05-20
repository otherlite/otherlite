---
description: 产品功能视角的 wiki —— 用户/产品角度的功能定义
domain: meta
---

# docs/features/

每个 markdown 文件描述**一个用户可感知的功能**，从产品角度回答 做了什么 / 为什么 / 怎么用。

## 写谁

- 用户/PM/客服能从这里理解功能边界与使用方式
- 新加入的工程师能从这里快速了解产品有什么

## 维护方

- 主要由 `wiki-curator` agent 在 `/ulw` 末段自动更新
- 手写补充必须包在 `<!-- HUMAN: start --> ... <!-- HUMAN: end -->` 保护块内，否则会被 `wiki-curator` 覆盖
- spec 里通过 frontmatter `affects_docs: [features/xxx]` 指定本次任务影响哪些页面

## 文件命名

`{feature-name}.md`，小写连字符。例如 `tiered-pricing.md`、`oauth-login.md`。

## frontmatter 必填

```yaml
---
description: 一句话功能定义（< 80 字符）
domain: features
last_updated_by_spec: {最近一次更新本页的 task-slug}
---
```

`description` 用于 L1→L2 编译生成 CLAUDE.md 索引，必填且高质量。
