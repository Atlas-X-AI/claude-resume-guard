# Open Issues

## 1. [security] Rotate leaked API keys from mcp-server-registry.json
`~/.claude/mcp-server-registry.json` still has plaintext keys on disk (Dropbox, DeepSeek, Perplexity, OpenAI, Railway). Git history purged but keys need rotation in their respective services.

## 2. [testing] Test chezmoi externals for 5 skills
5 skills in `.chezmoiexternal.toml` (codify, phase-engine, prd-taskmaster, research-before-coding, wtf) were configured but never tested with `chezmoi apply`.

## 3. [ops] Notify graciel (MacBook) about force-pushed chezmoi repo
Force-pushed cleaned history to `github.com/anombyte93/dotfiles.git`. Any clone needs: `git fetch && git reset --hard origin/main`.

## 4. [cleanup] Clean up guard-demo worktree and stale tmux sessions
`guard-demo` tmux session + worktree are stale. Also audit 28 tmux sessions for zombies.
