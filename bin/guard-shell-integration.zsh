# guard-shell-integration.zsh — Session resume guard integration for aw/awc aliases
#
# Source AFTER the aw/awc alias definitions in .zshrc:
#   source ~/Hermes/current-projects/session-resume-guard/bin/guard-shell-integration.zsh
#
# This replaces the `aw` alias with a function that checks session size
# before resuming. `awc` (fresh session) passes through unchanged.

# Override aw alias with guarded function
# In zsh, functions take precedence over aliases with the same name
unalias aw 2>/dev/null

aw() {
  # Only guard if the tool exists
  if command -v claude-resume-guard &>/dev/null; then
    claude-resume-guard "$(pwd)"
    local guard_exit=$?

    case $guard_exit in
      0)
        # Proceed with normal resume
        command claude --dangerously-skip-permissions --continue "$@"
        ;;
      1)
        # User cancelled
        return 0
        ;;
      2)
        # Fresh session was launched (in tmux split or directly)
        return 0
        ;;
    esac
  else
    # Guard not installed, fall back to direct claude
    command claude --dangerously-skip-permissions --continue "$@"
  fi
}
