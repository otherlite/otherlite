#!/usr/bin/env bash
# ulw-list.sh
# 列当前所有 ulw worktree。两列：slug + 绝对路径。

set -euo pipefail

git worktree list --porcelain | awk '
  /^worktree / { wt = substr($0, 10) }
  /^branch refs\/heads\/ulw\// {
    slug = substr($0, 22)  # strip "branch refs/heads/ulw/"
    printf "%-40s  %s\n", slug, wt
  }
'
