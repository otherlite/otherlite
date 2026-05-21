#!/usr/bin/env bash
# ulw-check.sh <slug>
# 探测 ulw worktree 启动前置状态，输出 key=value 到 stdout，供主会话解析决策。
# 失败信息走 stderr。

set -u

SLUG="${1:-}"
if [ -z "$SLUG" ]; then
  echo "Usage: $0 <slug>" >&2
  exit 2
fi

WORKTREE_PATH=".worktrees/ulw-${SLUG}"
BRANCH_NAME="ulw/${SLUG}"

# worktree 是否存在（目录在 OR git 知道）
if [ -d "$WORKTREE_PATH" ] || git worktree list 2>/dev/null | grep -Fq "$WORKTREE_PATH"; then
  WORKTREE_EXISTS=true
else
  WORKTREE_EXISTS=false
fi

# 分支是否存在（本地）
if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  BRANCH_EXISTS=true
else
  BRANCH_EXISTS=false
fi

# gh CLI
if command -v gh >/dev/null 2>&1; then
  GH_AVAILABLE=true
else
  GH_AVAILABLE=false
fi

# origin/main 可达（顺便 fetch；下游 create 不必再 fetch）
if git fetch origin main >/dev/null 2>&1; then
  ORIGIN_REACHABLE=true
else
  ORIGIN_REACHABLE=false
fi

cat <<EOF
worktree_exists=${WORKTREE_EXISTS}
worktree_path=${WORKTREE_PATH}
branch_exists=${BRANCH_EXISTS}
branch_name=${BRANCH_NAME}
gh_available=${GH_AVAILABLE}
origin_reachable=${ORIGIN_REACHABLE}
EOF
