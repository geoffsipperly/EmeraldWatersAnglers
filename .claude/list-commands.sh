#!/usr/bin/env bash
# Emits a SessionStart banner listing every custom slash command in
# .claude/commands/, derived from each command's `description:` frontmatter.
# Outputs both `systemMessage` (user-visible) and
# `hookSpecificOutput.additionalContext` (model-visible) so the list is
# reachable regardless of which surface Claude Code renders for SessionStart.
# Touches /tmp/claude-banner-fired so you can confirm the hook ran.
set -euo pipefail

date +%FT%T%z >> /tmp/claude-banner-fired 2>/dev/null || true

ROOT="${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}"
COMMANDS_DIR="$ROOT/.claude/commands"

if [ ! -d "$COMMANDS_DIR" ] || [ -z "$(ls -A "$COMMANDS_DIR"/*.md 2>/dev/null)" ]; then
  exit 0
fi

BANNER=$(awk '
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
' "$COMMANDS_DIR"/*.md)

jq -n --arg msg "$BANNER" '{
  systemMessage: $msg,
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $msg
  }
}'
