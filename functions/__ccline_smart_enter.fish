# Enter handler installed by conf.d/ccline.fish.
#
# Looks at the current command line. If it's a 2+-word "thought" (first
# token isn't an existing command/function/builtin), routes it to ccline
# *without* going through fish_command_not_found — so fish never prints its
# "^~^ Unknown command" caret. Otherwise, just defers to the default Enter
# behaviour (`commandline -f execute`).
#
# When ccline returns a chosen command via $__ccline_pending, we load it
# into the buffer with `commandline -r` instead of executing — the user
# reviews/edits/presses Enter again to run it through the normal pipeline
# (history records it just like any typed command).

function __ccline_smart_enter
    set -l line (commandline)
    set -l stripped (string trim -- $line)

    # Empty buffer → default behaviour (gives a fresh prompt).
    if test -z "$stripped"
        commandline -f execute
        return
    end

    # Tokenise on whitespace, drop empties.
    set -l words (string split -n ' ' -- $stripped)
    set -l first $words[1]

    # Single token, or first token IS a known command → run normally.
    # `type -q` covers builtins, functions, aliases, and binaries on PATH.
    if test (count $words) -lt 2; or type -q -- $first 2>/dev/null
        commandline -f execute
        return
    end

    # It's a thought. Take the line for ourselves.
    history append -- $stripped       # so ↑ recalls the question itself
    commandline -r ""                  # clear the buffer
    commandline -f repaint
    printf '\n'                        # advance past the prompt line

    # Run ccline in handler-mode: it shows menu, populates $__ccline_pending.
    set -g __ccline_handler_mode 1
    set -g __ccline_pending
    ccline $words
    set -e __ccline_handler_mode

    # Load the chosen command into the buffer for review/edit/run.
    if set -q __ccline_pending; and test (count $__ccline_pending) -gt 0
        commandline -r -- (string join '; and ' $__ccline_pending)
    end
    set -e __ccline_pending
end
