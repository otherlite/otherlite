#!/usr/bin/env bash
# ulw-pr-create.sh <slug> <body-file>
# 在 ulw/{slug} worktree 内调用：检查 status clean → push → gh pr create --draft → 输出 PR URL。
# 必须从 worktree cwd 调用，脚本会验证当前分支。

set -euo pipefail

SLUG="${1:-}"
BODY_FILE="${2:-}"

if [ -z "$SLUG" ] || [ -z "$BODY_FILE" ]; then
  echo "Usage: $0 <slug> <body-file>" >&2
  exit 2
fi

if [ ! -f "$BODY_FILE" ]; then
  echo "error: PR body 文件不存在: $BODY_FILE" >&2
  exit 1
fi

BRANCH_NAME="ulw/${SLUG}"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
  echo "error: 当前分支是 '${CURRENT_BRANCH}'，期望 '${BRANCH_NAME}'。请在 .worktrees/ulw-${SLUG}/ 内调用" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "error: 工作树非 clean，存在未提交改动：" >&2
  git status --short >&2
  exit 1
fi

git push -u origin "$BRANCH_NAME" >&2

PR_URL="$(gh pr create --draft --base main --head "$BRANCH_NAME" \
  --title "[ulw] ${SLUG}" \
  --body-file "$BODY_FILE")" || {
  echo "error: gh pr create 失败" >&2
  exit 1
}

echo "$PR_URL"
