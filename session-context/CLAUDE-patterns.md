# Patterns

## 07/04/2026 — Zsh echo vs printf
Zsh echo expands \n in variables by default. Use printf '%s' for raw strings, especially when piping JSON to jq.

## 07/04/2026 — Chezmoi .chezmoiignore scope
Only affects destination (chezmoi apply). Does NOT prevent files from being in the source repo. Must chezmoi forget + delete from source to fully remove.

## 07/04/2026 — while-read vs for-in-$(ls) in zsh
for f in $(ls ...) breaks in subshell command substitution. Use while IFS= read -r with <<< for reliable file iteration.
