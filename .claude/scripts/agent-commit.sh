#!/usr/bin/env bash
# agent-commit.sh <agent> <summary>
# 标准化的 ulw pipeline agent self-commit。
#
# 自动：
#   - 根据 agent 名推断 pipeline 节点序号
#   - stage 所有改动（git add -A）
#   - 无 staged 改动 → 静默跳过（idempotent，可重复调用）
#   - commit 消息格式 [ulw] {N}-{agent}: {summary}
#   - summary 超 50 字截断 + 末尾 "..."
#
# 用法示例：
#   bash .claude/scripts/agent-commit.sh analyst "用户登录限流需求"
#   bash .claude/scripts/agent-commit.sh developer-2 "实现 POST /foo 路由"
#   bash .claude/scripts/agent-commit.sh wiki-curator "改 3 个 features 页面"

set -euo pipefail

AGENT="${1:-}"
SUMMARY="${2:-}"

if [ -z "$AGENT" ] || [ -z "$SUMMARY" ]; then
  echo "Usage: $0 <agent> <summary>" >&2
  echo "  agent: analyst | architect | developer-{N} | qa | reviewer | security | wiki-curator" >&2
  exit 2
fi

case "$AGENT" in
  analyst)       NODE=1 ;;
  architect)     NODE=2 ;;
  developer-*)   NODE=3 ;;
  qa)            NODE=4 ;;
  reviewer)      NODE=5 ;;
  security)      NODE=6 ;;
  wiki-curator)  NODE=7 ;;
  *)
    echo "error: unknown agent '$AGENT'，无法推断节点序号" >&2
    exit 2
    ;;
esac

# 截 summary 到 50 字（按字符长度）
if [ ${#SUMMARY} -gt 50 ]; then
  SUMMARY="${SUMMARY:0:47}..."
fi

git add -A

if git diff --cached --quiet; then
  echo "info: no staged changes for ${AGENT}, skip commit" >&2
  exit 0
fi

git commit -m "[ulw] ${NODE}-${AGENT}: ${SUMMARY}" >/dev/null
echo "committed: [ulw] ${NODE}-${AGENT}: ${SUMMARY}"
