# Session Debrief — Session Resume Guard

**Date:** 2026-04-07
**Plan:** docs/superpowers/plans/2026-04-07-session-resume-guard.md
**Tests:** 0 (not yet implemented)
**Branch:** None yet — this is greenfield work in ~/scripting

## What Was Built (This Session)

| Item | Status |
|------|--------|
| Full implementation plan (5 tasks) | Complete — `docs/superpowers/plans/2026-04-07-session-resume-guard.md` |
| /question research (6 queries + dangling agent) | Complete — findings merged into plan |
| Phone-bridge Pointer class refactor | Complete — committed on phone-bridge `dev` branch |
| Phone-bridge race condition fix (tmux load-buffer) | Complete — committed |
| F10 tmux keybinding for `pb .` | Complete — chezmoi-tracked |
| Handoff gate architecture research | Complete — AskUserQuestion is the right primitive, not sentinel files |

## What's NOT Built Yet

| Task | What | Priority |
|------|------|----------|
| Task 1 | claude-resume-guard script + config | HIGH |
| Task 2 | claude-session-summarize (Gemini) | HIGH |
| Task 3 | Shell alias integration (aw/awc) | HIGH |
| Task 4 | SessionStart hook (bypass warning) | MEDIUM |
| Task 5 | Integration testing | HIGH |

## Architecture Decisions

1. **Shell wrapper, not Claude hook** — SessionStart hooks fire AFTER tokens are committed. The guard MUST intercept before `claude` binary launches. Shell function wrapping the `aw`/`awc` aliases is the correct interception point.

2. **Recency-gated warnings** — Prompt cache TTL is 5 minutes. If session was active <5min ago, cache is hot = 90% discount. Guard should skip warnings for recently-active sessions. Over 1 hour = full price, always warn.

3. **Fallback chain for summaries** — Priority: (a) session-context/*.md files if /sync was run, (b) Gemini Flash summarization of JSONL + insights, (c) raw last-N lines from JSONL. Never fail — always offer something.

4. **`--bare` + `--system-prompt-file` as ultra-light option** — Discovered during research. Could bypass full history AND Gemini by seeding a bare session with session-context files.

5. **Integration into claude-launcher** — Don't create a standalone tool. Hook into existing `shell-aliases.sh` where `aw`/`awc` are defined. User's muscle memory stays the same.

## Key Research Findings

- Session JSONL files range 1MB to 75MB (~20K to 8.8M tokens)
- ALL history is replayed client-side on resume — no server checkpointing
- Prompt caching: 5-min TTL (free), 1-hr TTL (paid). Cold cache = full price
- 78MB session: $26 uncached vs $2.63 cached — 10x difference
- No `--compact` CLI flag exists. `/compact` is in-session only
- `--fork-session` creates new session ID from resume point
- No prior art exists for resume guards — this is novel

## What to Question

1. **Is the 5MB threshold right?** 5MB ≈ 100K tokens ≈ $0.30. Maybe too aggressive — 10MB ($0.60) might be a better default.
2. **Should the guard work for `claude --resume <id>` too?** Current plan only hooks `aw`/`awc` aliases. Direct `claude --resume` bypasses the guard (SessionStart hook is the fallback, but it's post-hoc).
3. **Gemini API key storage** — Plan checks `~/.config/gemini/api-key` then Bitwarden. Is there a simpler path? Environment variable?
4. **Token estimation heuristic** — Dangling agent suggested `bytes × 0.45 / 4`. Validate this against actual JSONL content.
5. **Should guard auto-compact old sessions?** Instead of just warning, could it fork + compact automatically?
