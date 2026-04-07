# Troubleshooting

## 07/04/2026 — Guard doesn't block after fresh-start
**Cause:** Fresh -p session creates a tiny new JSONL that becomes "most recent". Guard sees it and passes through.
**Fix:** Skip files <500KB in session selection. Find first large interactive session.

## 07/04/2026 — Guard says "cache hot" on retry
**Cause:** File mtime updated on every resume attempt, even aborted ones.
**Fix:** Read last message timestamp from JSONL content, not file mtime.

## 07/04/2026 — Token estimate wildly wrong (5x too high)
**Cause:** Assumed bytes*0.45/4. Claude actually does ~bytes/43.
**Fix:** Calibrated against Claude's own 727.8K count for 31MB file.

## 07/04/2026 — Split pane empty after fresh-start
**Cause:** -p is non-interactive print mode (exits after response). Nested quoting in tmux command also broke.
**Fix:** Use --append-system-prompt-file for context + "/start" as positional prompt for interactive session.
