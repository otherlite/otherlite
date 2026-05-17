---
description: 安全审查 checklist —— 注入、AuthN/AuthZ、密钥、数据泄漏、依赖、基建
domain: security
---

# 安全审查 Checklist

带着这份清单走一遍改动。**不要只抽查 —— 跟着用户可控数据从入口走到落点。**

## 1. 输入处理

- **注入**：SQL（原始查询、字符串拼接、ORM `raw`/`unsafe`）、命令（`exec`/`spawn`/`system`/`eval`）、模板（SSTI）、LDAP、NoSQL、Header 注入、日志注入
- **XSS**：HTML/JSX 中未转义输出（`dangerouslySetInnerHTML`、`v-html`、`innerHTML`、模板字符串塞进 DOM），反射型和存储型
- **路径穿越**：任何从用户输入构造的文件路径 —— 检查 `..`、绝对路径、符号链接
- **SSRF**：带用户可控 URL/host 的出站请求 —— 验证用白名单而非黑名单
- **反序列化**：`pickle`、`yaml.load`（vs `safe_load`）、Java/PHP unserialize、JSON 原型污染

## 2. 认证 / 授权

- **认证**：每个受保护路由真的检查了身份。新端点继承了 auth 中间件（不要默认假设）。
- **授权**：对象级检查（IDOR）—— `getOrder(id)` 必须校验 `id` 属于当前用户。角色检查在服务端，永远不信客户端声明。
- **Session**：cookie 的 secure/httpOnly/sameSite、权限变更时轮换、登出后服务端失效、无 session fixation
- **Token**：JWT 算法锁死（禁 `alg: none`）、短过期、refresh 轮换、密钥不在仓库里

## 3. 密钥 & 加密

- **密钥**：无硬编码 key、`.env` 不入仓、日志/错误/URL 里无密钥
- **加密**：不自造加密、不用 MD5/SHA1 做安全用途、不用 ECB、IV 随机且不复用、密码用 bcrypt/argon2/scrypt（不是 SHA）、token 对比用常量时间
- **随机**：`crypto.randomBytes` / `secrets.token_*`，安全场景永远不用 `Math.random` / `random.random`

## 4. 数据泄漏

- **PII / 敏感数据**出现在日志、错误响应、API 响应（over-fetching）、客户端 bundle
- **错误消息**在生产环境泄漏 stack trace、查询结构、文件路径
- **CORS**：带凭据的端点不能是 `*`，origin 白名单显式列出
- **CSRF**：状态变更请求有 CSRF 防护或 SameSite 保护

## 5. 依赖 & 供应链

- 新依赖：typo-squat 检查、维护状态、已知 CVE（`npm audit` / `pip-audit`）
- Lockfile 更新且已提交
- 脚本里没加 `curl | sh` 这种安装步骤

## 6. 基础设施 / 配置

- 文件上传：按内容而非扩展名校验类型、大小限制、存在 web root 之外、无执行权限
- 鉴权端点、密码重置、昂贵操作有限流
- 敏感端点强制 TLS
- 合适场景下安全 header 到位（CSP、HSTS、X-Content-Type-Options）

## 7. 危险模式快速 grep 清单

跑 `git diff` 后对这些关键词扫一遍：

```
exec  eval  raw  dangerouslySet  innerHTML  pickle.load  yaml.load
Math.random  MD5  SHA1  alg.*none  child_process  subprocess.shell
process.env (写到响应)  console.log(.*token|password|secret)
```

## 8. 严重级别定义

- **Critical** —— 当前生产路径可利用（RCE、auth bypass、密钥泄漏、SQLi）
- **High** —— 有条件可利用，或敏感数据暴露
- **Medium** —— 纵深防御缺口、缺加固、风险模式但当前不可利用
- **Low / 提示** —— 偏离最佳实践、改进建议

## 9. 项目特定约定

> 随项目演进填充。当前为空。

- **威胁模型**（关键资产、可信边界、当前已知风险）：（待补充）
- **依赖白名单 / 黑名单**：（待补充）
- **密钥管理流程**（用什么 secrets manager、rotation 周期）：（待补充）
- **安全相关的合规约束**（GDPR / PCI / SOC2 等）：（待补充）
