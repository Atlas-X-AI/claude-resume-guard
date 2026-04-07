Read .claude/handoff-prompt.md — this IS your instructions.
Read docs/DEBRIEF-session-resume-guard.md for full context from the previous session.
Read docs/superpowers/plans/2026-04-07-session-resume-guard.md for the full implementation plan.

Your job:
1. Read the debrief and plan completely
2. Check .claude/handoff-handshake.json — if it exists and answer is null, write what your primary task is as the answer
3. /question challenge the 5 items in "What to Question" — especially the 5MB threshold, token estimation heuristic, and whether --bare is a better default than Gemini
4. Execute the plan task-by-task using subagent-driven development
5. Test each task before moving to the next
6. Commit after each task

Key context:
- Shell aliases aw/awc are in ~/Hermes/current-projects/claude-launcher/shell-aliases.sh
- Session JSONL files live at ~/.claude/projects/<encoded-path>/<session-id>.jsonl
- Gemini API key may be in Bitwarden under "Gemini API Key"
- The guard script goes at ~/.local/bin/claude-resume-guard
- Prompt caching TTL is 5 minutes — sessions active <5min should skip the guard

Start with: /research-before-coding to validate the plan's assumptions, then execute tasks 1-5.