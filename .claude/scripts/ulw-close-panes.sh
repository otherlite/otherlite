#!/usr/bin/env bash
# ulw-close-panes.sh <slug> [--dry-run]
# 关掉所有 cwd 落在 .worktrees/ulw-<slug>/ 下的 cmux pane（focused pane 除外）。
# 用于 ulw pipeline 节点 8 PR 创建后的统一清理。

set -euo pipefail

SLUG=""
DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 <slug> [--dry-run]" >&2
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
  echo "Usage: $0 <slug> [--dry-run]" >&2
  exit 2
fi

if ! command -v cmux >/dev/null 2>&1; then
  echo "info: cmux 不可用，跳过 pane 清理" >&2
  exit 0
fi

WORKTREE_FRAGMENT=".worktrees/ulw-${SLUG}"
CLOSED=0
KEPT=0

# cmux list-panes 输出格式（每行一个 pane）:
#   * pane:1  [1 surface]  [focused]
#     pane:2  [1 surface]
# focused 标记的 pane 永远跳过（保护主会话）。
while IFS= read -r line; do
  pane_ref="$(printf '%s\n' "$line" | grep -oE 'pane:[0-9]+' | head -1 || true)"
  [ -z "$pane_ref" ] && continue
  if printf '%s\n' "$line" | grep -q '\[focused\]'; then
    continue
  fi
  surface_info="$(cmux list-pane-surfaces --pane "$pane_ref" 2>/dev/null || true)"
  if ! printf '%s\n' "$surface_info" | grep -Fq "$WORKTREE_FRAGMENT"; then
    KEPT=$((KEPT + 1))
    continue
  fi
  surface_ref="$(printf '%s\n' "$surface_info" | grep -oE 'surface:[0-9]+' | head -1 || true)"
  [ -z "$surface_ref" ] && continue
  if [ "$DRY_RUN" = true ]; then
    echo "would close $pane_ref ($surface_ref)" >&2
  else
    cmux close-surface --surface "$surface_ref" >/dev/null 2>&1 || true
  fi
  CLOSED=$((CLOSED + 1))
done < <(cmux list-panes 2>/dev/null || true)

if [ "$DRY_RUN" = true ]; then
  echo "dry-run: 共 ${CLOSED} 个 pane 会被关，${KEPT} 个 pane 保留" >&2
else
  echo "closed ${CLOSED} pane(s); kept ${KEPT}" >&2
fi
