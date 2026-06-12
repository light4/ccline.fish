# Braille "thinking…" animation. Run as a *subprocess* (not in-process &):
# fish 4 silently blocks the parent when you background a fish function with
# &, so ccline spawns this via `fish -c ccline_spinner &` instead.
#
# Draws ONLY to /dev/tty so the parent's stdout (which a command substitution
# may be capturing) stays clean.

function ccline_spinner
    set -l tty /dev/tty
    set -l ESC \e
    set -l frames ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
    set -l n (count $frames)
    set -l i 1
    printf '%s[?25l' $ESC >$tty 2>/dev/null    # hide cursor
    while true
        printf '\r%s[2m%s thinking…%s[0m' $ESC $frames[$i] $ESC >$tty 2>/dev/null
        set i (math "($i % $n) + 1")
        sleep 0.1
    end
end
