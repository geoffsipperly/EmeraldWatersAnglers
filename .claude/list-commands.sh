#!/usr/bin/env bash
# Emits a SessionStart banner listing every custom slash command in
# .claude/commands/, derived from each command's `description:` frontmatter.
# Output is wrapped in {"systemMessage": "..."} so Claude Code surfaces it
# to the user at session start.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}"
COMMANDS_DIR="$ROOT/.claude/commands"

if [ ! -d "$COMMANDS_DIR" ] || [ -z "$(ls -A "$COMMANDS_DIR"/*.md 2>/dev/null)" ]; then
  exit 0
fi

awk '
  BEGIN { print "Custom slash commands (type / to autocomplete):" }
  FNR == 1 {
    name = FILENAME
    sub(/.*\//, "", name)
    sub(/\.md$/, "", name)
  }
  /^description:/ {
    sub(/^description: */, "")
    printf "  /%-12s %s\n", name, $0
  }
' "$COMMANDS_DIR"/*.md | jq -Rs '{systemMessage: .}'
