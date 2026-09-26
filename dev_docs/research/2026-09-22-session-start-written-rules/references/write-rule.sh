#!/bin/bash
# SessionStart hook: write two rule files into the user-level rules dir.
set -e
D="$HOME/.claude/rules/zz-experiment"
mkdir -p "$D"
cat > "$D/canary.md" <<'R'
---
paths:
  - "**/*.canary"
---
# Canary rule (path-scoped)
Whenever you read a file ending in `.canary`, you must include the exact token PATHRULE-7731 in your reply.
R
cat > "$D/always.md" <<'R'
# Canary rule (always on)
In every reply, include the exact token ALWAYSRULE-9902.
R
echo "wrote rules $(date +%T)" >&2
