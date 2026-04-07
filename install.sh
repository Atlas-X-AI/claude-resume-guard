#!/usr/bin/env bash
# install.sh — Install session resume guard to system paths
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing session resume guard..."

# Bin scripts
mkdir -p ~/.local/bin
for f in "$SCRIPT_DIR"/bin/*; do
  [[ -f "$f" ]] || continue
  cp "$f" ~/.local/bin/
  chmod +x ~/.local/bin/"$(basename "$f")"
  echo "  -> ~/.local/bin/$(basename "$f")"
done

# Config (don't overwrite existing)
mkdir -p ~/.config/claude-guard
if [[ ! -f ~/.config/claude-guard/config.json ]]; then
  cp "$SCRIPT_DIR/config/config.json" ~/.config/claude-guard/
  echo "  -> ~/.config/claude-guard/config.json"
else
  echo "  -- ~/.config/claude-guard/config.json (exists, skipped)"
fi

# Hooks
if [[ -f "$SCRIPT_DIR/hooks/session-resume-guard.sh" ]]; then
  mkdir -p ~/.claude/hooks
  cp "$SCRIPT_DIR/hooks/session-resume-guard.sh" ~/.claude/hooks/
  chmod +x ~/.claude/hooks/session-resume-guard.sh
  echo "  -> ~/.claude/hooks/session-resume-guard.sh"
fi

echo "Done. Ensure ~/.local/bin is in PATH."
