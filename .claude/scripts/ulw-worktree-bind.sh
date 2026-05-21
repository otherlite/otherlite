#!/usr/bin/env bash
# ulw-worktree-bind.sh <slug>
# 分支 ulw/{slug} 已存在但 worktree 不在时，绑定分支到新 worktree + 拷贝 includes。
# 成功时 stdout 输出 worktree 绝对路径。

set -euo pipefail

SLUG="${1:-}"
if [ -z "$SLUG" ]; then
  echo "Usage: $0 <slug>" >&2
  exit 2
fi

WORKTREE_PATH=".worktrees/ulw-${SLUG}"
BRANCH_NAME="ulw/${SLUG}"

if ! git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  echo "error: 分支 ${BRANCH_NAME} 不存在，无法绑定" >&2
  exit 1
fi

if [ -d "$WORKTREE_PATH" ]; then
  echo "error: ${WORKTREE_PATH} 已存在，请先 cleanup / rebuild" >&2
  exit 1
fi

git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" >/dev/null

if [ -f .worktreeinclude ]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue
    if [ -e "$line" ]; then
      mkdir -p "${WORKTREE_PATH}/$(dirname "$line")"
      cp -r "$line" "${WORKTREE_PATH}/$line"
    else
      echo "warn: .worktreeinclude 列出的 $line 在主仓库不存在，跳过" >&2
    fi
  done < .worktreeinclude
fi

( cd "$WORKTREE_PATH" && pwd )
