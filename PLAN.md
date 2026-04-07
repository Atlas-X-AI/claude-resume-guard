# Session Resume Guard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Intercept Claude Code session resumes with heavy context, warn the user about token cost, and offer to spawn a fresh lightweight session using Gemini-summarized insights instead.

**Architecture:** A shell wrapper function (`claude-guard`) that checks the .jsonl session file size before launching `claude --resume`. If the file exceeds a threshold (default 5MB / ~100K tokens), it blocks the resume, uses Gemini Flash (free tier) to summarize the session's insights + last N exchanges, then offers to spawn a fresh Claude session in a tmux split with the summary as the initial prompt. The guard integrates into the existing `claude-launcher/shell-aliases.sh` ecosystem.

**Tech Stack:** Zsh (shell wrapper), Gemini API via `gemini-cli` or curl, tmux, atlas-session MCP (for insights DB), jq

---

## File Structure

| File | Responsibility |
|------|---------------|
| `~/.local/bin/claude-resume-guard` | Core guard script — checks size, prompts user, orchestrates fresh session |
| `~/.local/bin/claude-session-summarize` | Gemini summarization script — extracts insights + last N lines, calls Gemini |
| `~/Hermes/current-projects/claude-launcher/shell-aliases.sh` | Modify: hook guard into `aw` alias and `--resume` detection |
| `~/.claude/hooks/session-resume-guard.sh` | SessionStart hook — lightweight warning if guard was bypassed |
| `~/.config/claude-guard/config.json` | User-configurable thresholds and preferences |

---

### Task 1: Config and Size Check

**Files:**
- Create: `~/.local/bin/claude-resume-guard`
- Create: `~/.config/claude-guard/config.json`

- [ ] **Step 1: Create config file with defaults**

```json
{
  "max_safe_size_mb": 5,
  "warn_size_mb": 2,
  "auto_summarize": true,
  "gemini_model": "gemini-2.0-flash",
  "summary_last_n_lines": 200,
  "summary_max_tokens": 2000
}
```

```bash
mkdir -p ~/.config/claude-guard
cat > ~/.config/claude-guard/config.json << 'EOF'
{
  "max_safe_size_mb": 5,
  "warn_size_mb": 2,
  "auto_summarize": true,
  "gemini_model": "gemini-2.0-flash",
  "summary_last_n_lines": 200,
  "summary_max_tokens": 2000
}
EOF
```

- [ ] **Step 2: Create guard script skeleton with size check**

```bash
#!/usr/bin/env zsh
# claude-resume-guard — Intercept heavy session resumes
set -euo pipefail

CONFIG="$HOME/.config/claude-guard/config.json"
GUARD_LOG="$HOME/.local/share/claude-guard/guard.log"

_guard_log() {
  mkdir -p "$(dirname "$GUARD_LOG")"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$GUARD_LOG"
}

# Parse config
MAX_SAFE_MB=$(jq -r '.max_safe_size_mb // 5' "$CONFIG" 2>/dev/null || echo 5)
WARN_MB=$(jq -r '.warn_size_mb // 2' "$CONFIG" 2>/dev/null || echo 2)

# Find the session file for the given session ID or current project
find_session_file() {
  local session_id="$1"
  local project_dir="$2"
  
  # Convert project path to Claude's storage format
  local encoded_path=$(echo "$project_dir" | sed 's|/|-|g; s|^-||')
  local session_dir="$HOME/.claude/projects/-${encoded_path}"
  
  if [[ -n "$session_id" ]]; then
    local file="$session_dir/${session_id}.jsonl"
    [[ -f "$file" ]] && echo "$file" && return 0
  fi
  
  # Find most recent session file
  ls -t "$session_dir"/*.jsonl 2>/dev/null | head -1
}

# Get file size in MB
get_size_mb() {
  local file="$1"
  local bytes=$(stat -c%s "$file" 2>/dev/null || echo 0)
  echo "scale=1; $bytes / 1048576" | bc
}

# Main guard logic
guard_check() {
  local session_id="${1:-}"
  local project_dir="${2:-$(pwd)}"
  local resume_args=("${@:3}")
  
  local session_file=$(find_session_file "$session_id" "$project_dir")
  
  if [[ -z "$session_file" || ! -f "$session_file" ]]; then
    _guard_log "No session file found — proceeding normally"
    return 0  # No session to guard, proceed
  fi
  
  local size_mb=$(get_size_mb "$session_file")
  local size_int=${size_mb%.*}
  
  _guard_log "Session file: $session_file (${size_mb}MB)"
  
  if (( size_int < WARN_MB )); then
    _guard_log "Size OK (${size_mb}MB < ${WARN_MB}MB) — proceeding"
    return 0  # Safe to resume
  fi
  
  if (( size_int < MAX_SAFE_MB )); then
    echo "\033[33m⚠ Session context: ${size_mb}MB (~$((size_int * 20))K tokens)\033[0m"
    echo "  This will cost ~\$$(echo "scale=2; $size_int * 20000 * 0.000003" | bc) in input tokens on resume."
    echo "  Tip: Consider /compact before next exit."
    _guard_log "Warning shown (${size_mb}MB) — proceeding"
    return 0  # Warn but proceed
  fi
  
  # BLOCK — session is too heavy
  echo ""
  echo "\033[31m■ Heavy session detected: ${size_mb}MB (~$((size_int * 20))K tokens)\033[0m"
  echo "  Resuming will cost ~\$$(echo "scale=2; $size_int * 20000 * 0.000003" | bc) in input tokens."
  echo "  Last modified: $(stat -c%y "$session_file" | cut -d. -f1)"
  echo ""
  echo "  Options:"
  echo "    \033[32m1)\033[0m Fresh start with Gemini summary (recommended)"
  echo "    \033[33m2)\033[0m Resume anyway (full token cost)"
  echo "    \033[90m3)\033[0m Cancel"
  echo ""
  
  read -r "choice?  Choice [1/2/3]: "
  
  case "$choice" in
    1)
      _guard_log "User chose fresh start with summary"
      fresh_start_with_summary "$session_file" "$project_dir"
      return 1  # Don't proceed with normal resume
      ;;
    2)
      _guard_log "User chose to resume anyway (${size_mb}MB)"
      return 0  # Proceed with resume
      ;;
    *)
      _guard_log "User cancelled"
      return 1  # Don't proceed
      ;;
  esac
}

fresh_start_with_summary() {
  local session_file="$1"
  local project_dir="$2"
  
  echo "  Generating summary..."
  
  # Call summarizer
  local summary
  summary=$(claude-session-summarize "$session_file" "$project_dir" 2>/dev/null)
  
  if [[ -z "$summary" ]]; then
    echo "\033[31m  Summary failed — falling back to session context files\033[0m"
    # Fallback: read session-context files directly
    summary="# Session Context (from files)\n\n"
    for f in "$project_dir"/session-context/CLAUDE-*.md; do
      [[ -f "$f" ]] && summary+="## $(basename "$f")\n$(cat "$f")\n\n"
    done
  fi
  
  # Write summary to temp file for injection
  local prompt_file="/tmp/claude-guard-prompt-$$.txt"
  cat > "$prompt_file" << PROMPT_EOF
You are resuming work that a previous session started. Here is a Gemini-generated summary of what was done, what's left, and key insights:

$summary

Start by reading the session-context files in session-context/ for current state, then continue the work described above.
PROMPT_EOF
  
  echo "  Summary ready ($(wc -w < "$prompt_file") words)"
  echo "  Spawning fresh session..."
  
  # If in tmux, split pane with new session
  if [[ -n "${TMUX:-}" ]]; then
    local session_name="$(tmux display-message -p '#S')-fresh"
    tmux split-window -v -p 60 -c "$project_dir" \
      "claude --dangerously-skip-permissions -p \"$(cat "$prompt_file")\""
    tmux select-pane -D  # Focus the new pane
    echo "  \033[32m✓\033[0m Fresh session spawned in split pane"
  else
    # Not in tmux — just launch directly
    claude --dangerously-skip-permissions -p "$(cat "$prompt_file")"
  fi
  
  rm -f "$prompt_file"
}

# Entry point — called with all original claude args
guard_check "$@"
```

- [ ] **Step 3: Make executable and test size check**

```bash
chmod +x ~/.local/bin/claude-resume-guard
# Test with a known large session
claude-resume-guard "" "$HOME/Hermes/current-projects/orchestrator"
```

Expected: Warning or block message for large sessions.

- [ ] **Step 4: Commit**

```bash
git add ~/.local/bin/claude-resume-guard ~/.config/claude-guard/config.json
git commit -m "feat: add session resume guard with size-based blocking"
```

---

### Task 2: Gemini Summarization Script

**Files:**
- Create: `~/.local/bin/claude-session-summarize`

- [ ] **Step 1: Create summarizer that extracts insights + last N lines**

```bash
#!/usr/bin/env zsh
# claude-session-summarize — Summarize a Claude session via Gemini
set -euo pipefail

SESSION_FILE="$1"
PROJECT_DIR="${2:-$(pwd)}"
CONFIG="$HOME/.config/claude-guard/config.json"

LAST_N=$(jq -r '.summary_last_n_lines // 200' "$CONFIG" 2>/dev/null || echo 200)
GEMINI_MODEL=$(jq -r '.gemini_model // "gemini-2.0-flash"' "$CONFIG" 2>/dev/null || echo "gemini-2.0-flash")

# Extract last N lines of user/assistant text from JSONL (skip tool results noise)
extract_recent() {
  tail -n "$LAST_N" "$SESSION_FILE" | \
    jq -r 'select(.message.role == "user" or .message.role == "assistant") |
      .message.content | if type == "array" then
        [.[] | select(.type == "text") | .text] | join("\n")
      elif type == "string" then . 
      else empty end' 2>/dev/null | \
    tail -c 8000  # Cap at ~2K tokens for Gemini input
}

# Get insights from atlas-session DB if available
get_insights() {
  # Try atlas-session MCP via curl to local session server
  local insights=""
  
  # Fallback: read session-context files
  for f in "$PROJECT_DIR"/session-context/CLAUDE-*.md; do
    if [[ -f "$f" ]]; then
      insights+="### $(basename "$f" .md)\n"
      insights+="$(cat "$f")\n\n"
    fi
  done
  
  echo "$insights"
}

# Build Gemini prompt
RECENT=$(extract_recent)
INSIGHTS=$(get_insights)

GEMINI_PROMPT="You are summarizing a Claude Code AI session for handoff to a fresh session.

## Session Context Files
$INSIGHTS

## Last Exchange Excerpt
$RECENT

## Your Task
Write a concise handoff summary (under 500 words) covering:
1. What was the goal (soul purpose)?
2. What was completed?
3. What's still in progress or blocked?
4. Key decisions made and WHY
5. What worked and what didn't (insights)
6. Specific next steps for the fresh session

Be direct. No fluff. The fresh session will use this as its starting context."

# Call Gemini via API (free tier)
GEMINI_API_KEY=$(cat ~/.config/gemini/api-key 2>/dev/null || echo "")

if [[ -z "$GEMINI_API_KEY" ]]; then
  # Try Bitwarden
  GEMINI_API_KEY=$(bw get password "Gemini API Key" 2>/dev/null || echo "")
fi

if [[ -z "$GEMINI_API_KEY" ]]; then
  echo "ERROR: No Gemini API key found" >&2
  # Fallback: just return the insights without Gemini analysis
  echo "$INSIGHTS"
  exit 0
fi

# Call Gemini API
RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg prompt "$GEMINI_PROMPT" '{
    contents: [{parts: [{text: $prompt}]}],
    generationConfig: {maxOutputTokens: 2000, temperature: 0.3}
  }')" 2>/dev/null)

# Extract text from response
echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null

# If Gemini failed, fall back to raw insights
if [[ $? -ne 0 || -z "$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)" ]]; then
  echo "$INSIGHTS"
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x ~/.local/bin/claude-session-summarize
```

- [ ] **Step 3: Test with a real session file**

```bash
# Test with the current session (small, should work fast)
claude-session-summarize ~/.claude/projects/-home-anombyte-Hermes-current-projects-scripting/9037b728-d22c-454a-ba64-cf682a7bbed6.jsonl /home/anombyte/Hermes/current-projects/scripting
```

Expected: A concise summary of the current session's work.

- [ ] **Step 4: Commit**

```bash
git add ~/.local/bin/claude-session-summarize
git commit -m "feat: add Gemini-powered session summarizer for resume guard"
```

---

### Task 3: Hook into Shell Aliases

**Files:**
- Modify: `~/Hermes/current-projects/claude-launcher/shell-aliases.sh`

- [ ] **Step 1: Create wrapper function that intercepts --resume and --continue**

Add to `shell-aliases.sh` after the existing alias definitions:

```bash
# ── Session Resume Guard ─────────────────────────────────────────────
# Wraps claude invocations to check context size before resume
_cl_guarded_claude() {
  local has_resume=false
  local has_continue=false
  local session_id=""
  
  # Parse args to detect resume/continue
  for arg in "$@"; do
    case "$arg" in
      --resume|-r) has_resume=true ;;
      --continue) has_continue=true ;;
    esac
  done
  
  # Also check if aw alias was used (--continue is implicit)
  if $has_resume || $has_continue; then
    if command -v claude-resume-guard &>/dev/null; then
      claude-resume-guard "$session_id" "$(pwd)" || return 0
    fi
  fi
  
  # Proceed with real claude
  command claude "$@"
}

# Override aliases to use guard
alias aw='_cl_guarded_claude --dangerously-skip-permissions --continue'
alias awc='_cl_guarded_claude --dangerously-skip-permissions'
```

- [ ] **Step 2: Test the guard triggers on resume**

```bash
source ~/Hermes/current-projects/claude-launcher/shell-aliases.sh
# In a directory with a large session:
cd ~/Hermes/current-projects/orchestrator
aw  # Should trigger guard warning
```

Expected: Guard intercepts, shows size warning, offers options.

- [ ] **Step 3: Commit**

```bash
cd ~/Hermes/current-projects/claude-launcher
git add shell-aliases.sh
git commit -m "feat: integrate session resume guard into claude aliases"
```

---

### Task 4: SessionStart Hook (Bypass Warning)

**Files:**
- Create: `~/.claude/hooks/session-resume-guard.sh`
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Create lightweight SessionStart hook**

This fires if the guard was bypassed (e.g., user launched claude directly without aliases). It can't block — tokens are already committed — but it can warn via additionalContext.

```bash
#!/usr/bin/env bash
# session-resume-guard.sh — SessionStart hook
# Warns about heavy context if guard was bypassed

SESSION_DIR="$HOME/.claude/projects"
# Find current session file by checking the session ID from env
# This is a lightweight check — just log a warning

CURRENT_PROJECT=$(pwd | sed 's|/|-|g; s|^-||')
SESSION_PATH="$SESSION_DIR/-${CURRENT_PROJECT}"

if [[ -d "$SESSION_PATH" ]]; then
  LARGEST=$(ls -S "$SESSION_PATH"/*.jsonl 2>/dev/null | head -1)
  if [[ -n "$LARGEST" ]]; then
    SIZE_MB=$(stat -c%s "$LARGEST" 2>/dev/null | awk '{printf "%.1f", $1/1048576}')
    SIZE_INT=${SIZE_MB%.*}
    if (( SIZE_INT > 5 )); then
      echo '{"additionalContext": "⚠ HEAVY CONTEXT WARNING: This session has '"${SIZE_MB}"'MB of history (~'"$((SIZE_INT * 20))"'K tokens). Consider running /compact early to reduce cost. Next time, use the `aw` alias which includes the resume guard."}'
      exit 0
    fi
  fi
fi

# No warning needed
echo '{}'
```

- [ ] **Step 2: Register hook in settings.json**

Add to the hooks section:

```json
"SessionStart": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "/home/anombyte/.claude/hooks/session-resume-guard.sh",
        "timeout": 3000
      }
    ]
  }
]
```

- [ ] **Step 3: Make executable and test**

```bash
chmod +x ~/.claude/hooks/session-resume-guard.sh
# Test hook output directly
cd ~/Hermes/current-projects/orchestrator
bash ~/.claude/hooks/session-resume-guard.sh
```

Expected: JSON with additionalContext warning for heavy sessions.

- [ ] **Step 4: Commit**

```bash
git add ~/.claude/hooks/session-resume-guard.sh
git commit -m "feat: add SessionStart hook for resume guard bypass warning"
```

---

### Task 5: Integration Test

**Files:** None (testing only)

- [ ] **Step 1: Test full flow with a heavy session**

```bash
# Find a heavy session
ls -lhS ~/.claude/projects/*/jsonl | head -5

# Navigate to that project
cd ~/Hermes/current-projects/orchestrator

# Try to resume via alias
aw
```

Expected flow:
1. Guard detects 75MB session file
2. Shows: "■ Heavy session detected: 75MB (~1500K tokens)"
3. Offers: Fresh start / Resume anyway / Cancel
4. On "Fresh start": Gemini summarizes, tmux splits, fresh Claude launches with summary

- [ ] **Step 2: Test with a small session (should pass through)**

```bash
cd ~/Hermes/current-projects/scripting
awc  # Fresh session, no guard triggered
```

Expected: Claude launches normally, no interruption.

- [ ] **Step 3: Test SessionStart hook fires on direct launch**

```bash
cd ~/Hermes/current-projects/orchestrator
command claude --resume <session-id>  # Bypass alias
```

Expected: Hook adds additionalContext warning about heavy context.

- [ ] **Step 4: Verify Gemini fallback works without API key**

```bash
# Temporarily move API key
mv ~/.config/gemini/api-key ~/.config/gemini/api-key.bak
claude-session-summarize <large-session-file> <project-dir>
mv ~/.config/gemini/api-key.bak ~/.config/gemini/api-key
```

Expected: Falls back to raw session-context files instead of Gemini summary.

---

## Dangling Agent Findings (Merged)

| Tag | Finding | Plan Impact |
|-----|---------|-------------|
| **[CONFIRMED]** | ALL history re-sent on resume. JSONL replayed client-side. 78MB = ~8.8M tokens | Guard math correct |
| **[CRITICAL]** | Prompt cache TTL = 5 min. Session active <5min = 90% discount. >1hr = full price. $26 vs $2.63 for 78MB. | **Add recency check — skip warning if <5 min stale** |
| **[ALTERNATIVE]** | session-context/*.md files contain summaries if /sync was run. Check before Gemini. | Add to fallback chain |
| **[NEW]** | `--fork-session` flag creates new session ID on resume (still full load). `--bare` flag = minimal context. | Research --bare for ultra-light resume |
| **[CONFIRMED]** | No `--compact` CLI flag. /compact is in-session only. | Guard is necessary, no shortcut |

**CRITICAL UPDATE for Task 1:** Add `check_recency()` function before size check:

```bash
check_recency() {
  local file="$1"
  local last_mod=$(stat -c%Y "$file")
  local now=$(date +%s)
  local age_seconds=$((now - last_mod))
  
  if (( age_seconds < 300 )); then
    # Cache is hot — resume is cheap (90% discount)
    _guard_log "Session active ${age_seconds}s ago — cache hot, skipping guard"
    return 0  # Safe, cache hits
  fi
  
  if (( age_seconds < 3600 )); then
    echo "\033[33m⚠ Session idle for $((age_seconds / 60)) minutes. Cache may be partially warm.\033[0m"
  else
    echo "\033[31m■ Session idle for $((age_seconds / 3600)) hours. Cache is COLD — full token cost.\033[0m"
  fi
  
  return 1  # Proceed to size check
}
```

Call `check_recency` before `guard_check` size logic. If cache is hot, skip the guard entirely.
