#!/usr/bin/env bash
# ulw-worktree-create.sh <slug>
# 从 origin/main 建分支 ulw/{slug} + worktree .worktrees/ulw-{slug}，
# 拷贝 .worktreeinclude 列出的文件。前置假设：ulw-check 已通过，无冲突。
# 成功时 stdout 输出 worktree 绝对路径；失败 exit non-zero。

set -euo pipefail

SLUG="${1:-}"
if [ -z "$SLUG" ]; then
  echo "Usage: $0 <slug>" >&2
  exit 2
fi

WORKTREE_PATH=".worktrees/ulw-${SLUG}"
BRANCH_NAME="ulw/${SLUG}"

# 防御性 fetch
git fetch origin main >/dev/null 2>&1 || {
  echo "error: 无法 fetch origin/main" >&2
  exit 1
}

git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" origin/main >/dev/null

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

# 输出绝对路径方便主会话 cd
( cd "$WORKTREE_PATH" && pwd )
