#!/usr/bin/env bash
# ulw-worktree-rebuild.sh <slug>
# 强删现有 worktree + 本地分支后重建。等价于：cleanup --delete-branch + create

set -euo pipefail

SLUG="${1:-}"
if [ -z "$SLUG" ]; then
  echo "Usage: $0 <slug>" >&2
  exit 2
fi

WORKTREE_PATH=".worktrees/ulw-${SLUG}"
BRANCH_NAME="ulw/${SLUG}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if git worktree list 2>/dev/null | grep -Fq "$WORKTREE_PATH"; then
  git worktree remove --force "$WORKTREE_PATH" >/dev/null
fi
git worktree prune >/dev/null

if [ -d "$WORKTREE_PATH" ]; then
  rm -rf "$WORKTREE_PATH"
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  git branch -D "$BRANCH_NAME" >/dev/null
fi

exec "$SCRIPT_DIR/ulw-worktree-create.sh" "$SLUG"
