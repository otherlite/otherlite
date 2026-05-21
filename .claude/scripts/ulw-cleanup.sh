#!/usr/bin/env bash
# ulw-cleanup.sh <slug> [--delete-branch]
# 删 worktree。默认保留本地分支（便于回滚 / 二次推送）；加 --delete-branch 才删本地分支。

set -euo pipefail

SLUG=""
DELETE_BRANCH=false

while [ $# -gt 0 ]; do
  case "$1" in
    --delete-branch) DELETE_BRANCH=true; shift ;;
    -h|--help)
      echo "Usage: $0 <slug> [--delete-branch]" >&2
      exit 0
      ;;
    *)
      if [ -z "$SLUG" ]; then
        SLUG="$1"
        shift
      else
        echo "unknown arg: $1" >&2
        exit 2
      fi
      ;;
  esac
done

if [ -z "$SLUG" ]; then
  echo "Usage: $0 <slug> [--delete-branch]" >&2
  exit 2
fi

WORKTREE_PATH=".worktrees/ulw-${SLUG}"
BRANCH_NAME="ulw/${SLUG}"

if git worktree list 2>/dev/null | grep -Fq "$WORKTREE_PATH"; then
  git worktree remove "$WORKTREE_PATH" >/dev/null
elif [ -d "$WORKTREE_PATH" ]; then
  echo "warn: ${WORKTREE_PATH} 存在但不在 git worktree list，rm -rf + prune" >&2
  rm -rf "$WORKTREE_PATH"
  git worktree prune
else
  echo "info: ${WORKTREE_PATH} 不存在，跳过 worktree 清理" >&2
fi

if [ "$DELETE_BRANCH" = true ]; then
  if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    git branch -D "$BRANCH_NAME" >/dev/null
    echo "deleted local branch ${BRANCH_NAME}" >&2
  else
    echo "info: 分支 ${BRANCH_NAME} 不存在，跳过分支清理" >&2
  fi
fi

echo "cleaned up ulw-${SLUG}"
