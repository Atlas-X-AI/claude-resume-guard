# claude-resume-guard

Intercept heavy Claude Code session resumes before they burn through your token budget.

When you resume a session with a large conversation history, Claude replays the entire JSONL file as input tokens. A 30MB session costs ~$10 uncached. This guard warns you before that happens and offers cheaper alternatives.

## What It Does

```
$ aw
■ Heavy session detected: 29.5MB (~721K tokens) | Idle 184h | Cache COLD
  Cost: ~$10.82 uncached | ~$1.08 cached
  File: 32526a45-2e3a-4ece-ac96-817e2ffa50b3.jsonl
  Modified: 2026-03-30 20:18:43

  Options:
    1) Fresh start with Gemini summary (recommended)
    2) Resume anyway (full token cost)
    3) Resume with --bare (minimal context, no hooks)
    4) Cancel
```

**Option 1** calls Gemini Flash (free tier) to summarize the old session, then spawns a fresh Claude session with that summary as context and `/start` as the kick-off prompt. You get the knowledge without the token cost.

## How It Works

- **Shell wrapper** intercepts `aw` (or any alias you configure) *before* Claude launches
- Checks the JSONL session file size and cache recency (prompt cache TTL = 5 min)
- If the session is small (<2MB) or the cache is hot (<5 min old), passes through silently
- If the session is large (>5MB) and cache is cold (>5 min), shows the warning menu
- **SessionStart hook** (fallback) warns via `additionalContext` if someone bypasses the guard

### Smart Session Detection

- Skips tiny sessions from `-p` (print mode) that `--continue` wouldn't resume
- Uses the **last message timestamp** from inside the JSONL, not the file modification time (which gets updated on every resume attempt)
- Token estimation calibrated against Claude's actual count: `bytes / 43`

## Install

```bash
npm install -g claude-resume-guard
```

Or manually:

```bash
git clone https://github.com/atlas-ai-au/claude-resume-guard.git
cd claude-resume-guard
./install.sh
```

### Post-Install Setup

Add to your `.zshrc` or `.bashrc` after your Claude aliases:

```bash
# If you use an alias like: alias aw='claude --dangerously-skip-permissions --continue'
# Source the guard integration AFTER the alias definition:
source /path/to/claude-resume-guard/bin/guard-shell-integration.zsh
```

The guard replaces your `aw` alias with a function that checks session size first. `awc` (fresh session) passes through unchanged.

### Gemini Summary (Optional)

For option 1 (fresh start with summary), you need a Gemini API key:

```bash
# Via environment variable (recommended)
export GEMINI_API_KEY="your-key-here"

# Or via file
echo "your-key-here" > ~/.config/gemini/api-key
```

Free tier Gemini Flash is sufficient. Without a key, the guard falls back to raw `session-context/` files.

## Configuration

Edit `~/.config/claude-guard/config.json`:

```json
{
  "max_safe_size_mb": 5,
  "warn_size_mb": 2,
  "auto_summarize": true,
  "gemini_model": "gemini-2.0-flash",
  "summary_last_n_lines": 200,
  "summary_max_tokens": 2000,
  "cache_hot_seconds": 300,
  "cache_warm_seconds": 3600
}
```

| Setting | Default | Description |
|---------|---------|-------------|
| `max_safe_size_mb` | 5 | Block threshold (MB). Sessions above this trigger the full menu. |
| `warn_size_mb` | 2 | Warning threshold (MB). Shows a yellow notice but proceeds. |
| `cache_hot_seconds` | 300 | Skip guard if session was active within this window (prompt cache is hot). |
| `cache_warm_seconds` | 3600 | Show "partially warm" instead of "COLD" within this window. |
| `gemini_model` | `gemini-2.0-flash` | Model for summarization. Free tier flash is fine. |

## Components

| File | Purpose |
|------|---------|
| `bin/claude-resume-guard` | Core guard script. Checks size, recency, shows menu. |
| `bin/claude-session-summarize` | Gemini Flash summarizer. Extracts context + last N exchanges. |
| `bin/guard-shell-integration.zsh` | Replaces `aw` alias with guarded function. |
| `hooks/session-resume-guard.sh` | SessionStart hook for bypass detection. |
| `config/config.json` | Default configuration. |

## Requirements

- `zsh` (for shell integration) or `bash` (for the guard script itself)
- `jq` (JSON parsing)
- `bc` (arithmetic)
- `tmux` (for split-pane fresh starts)
- Claude Code CLI (`claude`)
- Gemini API key (optional, for summaries)

## How Token Estimation Works

Claude replays the entire JSONL conversation on resume. The guard estimates tokens as:

```
tokens = file_size_bytes / 43
```

This was calibrated against Claude's own token count: a 31MB file = 727.8K tokens (Claude's number) vs 721K (our estimate). The ratio is ~43 bytes per token because JSONL includes JSON structure overhead that doesn't become tokens.

## License

MIT - Atlas AI Pty Ltd
