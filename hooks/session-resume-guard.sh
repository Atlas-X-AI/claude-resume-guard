#!/usr/bin/env bash
# session-resume-guard.sh — SessionStart hook
#
# Fires when Claude starts a session. If the user bypassed the shell guard
# (e.g., launched claude directly instead of using aw alias), this hook
# adds an additionalContext warning about heavy context.
#
# This is post-hoc — tokens are already committed — but it reminds the user
# to /compact early and use the aw alias next time.

CURRENT_PROJECT=$(pwd | sed 's|/|-|g; s|^-||')
SESSION_PATH="$HOME/.claude/projects/-${CURRENT_PROJECT}"

if [[ ! -d "$SESSION_PATH" ]]; then
  echo '{}'
  exit 0
fi

# Find the most recent session file
LATEST=$(ls -t "$SESSION_PATH"/*.jsonl 2>/dev/null | head -1)

if [[ -z "$LATEST" || ! -f "$LATEST" ]]; then
  echo '{}'
  exit 0
fi

SIZE_BYTES=$(stat -c%s "$LATEST" 2>/dev/null || echo 0)
SIZE_MB=$((SIZE_BYTES / 1048576))

# Only warn if session is over 5MB
if (( SIZE_MB >= 5 )); then
  TOKENS_K=$((SIZE_BYTES / 43 / 1000))
  cat <<WARN_EOF
{"additionalContext": "SESSION GUARD: This session has ${SIZE_MB}MB of context (~${TOKENS_K}K tokens). Consider running /compact early to reduce cost. Use the \`aw\` alias next time for the resume guard which can offer a fresh Gemini-summarized start."}
WARN_EOF
  exit 0
fi

echo '{}'
