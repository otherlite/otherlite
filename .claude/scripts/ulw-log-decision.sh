#!/usr/bin/env bash
# ulw-log-decision.sh <slug> <node> <agent> <verdict> <decision> <reason> [blockers]
# 主会话在 autopilot 模式下做出自动裁决时调用。
# append 一条记录到 docs/specs/<slug>/autopilot-log.md 并 commit。
#
# 参数：
#   slug      —— 任务 slug
#   node      —— 节点序号（1-7）
#   agent     —— agent 名（如 analyst / architect / developer-2 / qa / reviewer / security / wiki-curator）
#   verdict   —— agent 返回的原始 verdict
#   decision  —— 主会话决定（一句话）
#   reason    —— 决定的理由（一句话）
#   blockers  —— 可选，agent 给出的 blockers 摘要（多条用 "；" 分隔）
#
# 例：
#   bash .claude/scripts/ulw-log-decision.sh tiered-pricing-2026-05-21 4 qa fail \
#     "记入 PR body 继续节点 5" "autopilot 不在 pipeline 内重试" \
#     "test foo.test.ts:42 期望 201 实际 500"

set -euo pipefail

if [ $# -lt 6 ]; then
  echo "Usage: $0 <slug> <node> <agent> <verdict> <decision> <reason> [blockers]" >&2
  exit 2
fi

SLUG="$1"
NODE="$2"
AGENT="$3"
VERDICT="$4"
DECISION="$5"
REASON="$6"
BLOCKERS="${7:-}"

SPEC_DIR="docs/specs/${SLUG}"
LOG="${SPEC_DIR}/autopilot-log.md"

if [ ! -d "$SPEC_DIR" ]; then
  echo "error: ${SPEC_DIR} 不存在，无法记录裁决" >&2
  exit 1
fi

if [ ! -f "$LOG" ]; then
  cat > "$LOG" <<EOF
# Autopilot 自动裁决记录 — ${SLUG}

主会话在 autopilot 模式下每次替用户做出决定时 append 一条。节点 8 PR body 汇总此文件。

EOF
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "---"
  echo ""
  echo "## ${TS} · 节点 ${NODE} · ${AGENT}"
  echo ""
  echo "- **原始 verdict**: \`${VERDICT}\`"
  if [ -n "$BLOCKERS" ]; then
    echo "- **blockers**: ${BLOCKERS}"
  fi
  echo "- **主会话决定**: ${DECISION}"
  echo "- **理由**: ${REASON}"
  echo ""
} >> "$LOG"

git add "$LOG"

if git diff --cached --quiet -- "$LOG"; then
  echo "info: nothing to commit for autopilot-log" >&2
  exit 0
fi

git commit -m "[ulw] autopilot decision: ${AGENT}/${VERDICT}" >/dev/null
echo "logged: ${AGENT}/${VERDICT} → ${LOG}"
