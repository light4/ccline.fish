# ccline — zsh integration.
#
# Source this from ~/.zshrc:
#     source ~/.config/ccline/ccline.zsh
#
# When you type something that isn't a real command, zsh hands the whole line
# to command_not_found_handler. A single unknown word is treated as a normal
# typo (the usual "command not found"). Two or more words are treated as a
# thought and routed to the `ccline` helper, which asks Claude.
#
# The helper renders the answer and shows the command menu, but it does NOT run
# the chosen command itself. It writes the selection to $CCLINE_RUN_FILE and
# this handler evals it — so the command runs in YOUR live shell, where cd,
# export, aliases, functions, and history all work as expected.

# Let unmatched globs (a trailing "?" etc.) pass through as literal text so a
# question like "how do I do X?" reaches the handler instead of erroring.
setopt no_nomatch 2>/dev/null

command_not_found_handler() {
  # Two or more words AND the helper is actually installed → ask Claude.
  # The $+commands check also prevents infinite recursion if ccline is missing.
  if (( $# >= 2 )) && (( $+commands[ccline] )); then
    local runfile
    runfile="$(mktemp "${TMPDIR:-/tmp}/ccline.XXXXXX")" || {
      command ccline "$@"; return $?
    }

    CCLINE_RUN_FILE="$runfile" command ccline "$@"
    local rc=$?

    if [[ -s "$runfile" ]]; then
      # Run the chosen command(s) in this interactive shell.
      local line
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        print -r -- "$ $line"
        eval "$line" || { rc=$?; break }
      done < "$runfile"
    fi

    rm -f "$runfile"
    return $rc
  fi

  # Single token, or helper not installed: behave like a normal shell.
  print -u2 "zsh: command not found: $1"
  return 127
}
