# ccline — type a thought at your fish prompt, get an answer.
#
# Autoloaded by fish when you call `ccline` (the function below). The handler
# in conf.d/ccline.fish invokes this on unknown 2+-word "commands"; you can
# also run `ccline …` directly.
#
# When invoked from the handler, the handler sets $__ccline_handler_mode; in
# that case ccline writes the user's chosen commands to the global
# $__ccline_pending list instead of running them itself. The handler then
# evals each one in the user's live shell so cd / set / abbrs all persist.

function ccline_system_prompt
    echo 'You are a command-line assistant answering a quick question typed directly at a
macOS fish prompt. Be concise — a few sentences at most. If your answer involves
shell commands the user can run, put each runnable command in its own fenced
```bash code block. Never put example output, file contents, or non-runnable
snippets in a bash/sh/shell block. Prefer safe, non-destructive commands; if a
command is destructive, say so plainly.'
end

# Decide which LLM CLI to use. claude takes precedence; codex is the fallback.
# CCLINE_BACKEND=claude|codex forces a choice (if that CLI is installed).
function ccline_backend
    if set -q CCLINE_BACKEND; and test -n "$CCLINE_BACKEND"; and command -q -- "$CCLINE_BACKEND"
        echo "$CCLINE_BACKEND"
        return 0
    end
    if command -q claude
        echo claude
    else if command -q codex
        echo codex
    end
end

# Ask via the claude CLI. Clean, isolated call: no default agent prompt, tools,
# settings, or MCP. Echoes the answer; returns claude's exit status.
function ccline_ask_claude
    set -l prompt $argv[1]
    set -l sys $argv[2]
    # Sonnet 4.6 by default: fastest end-to-end for these short prompts and
    # plenty capable. Override with CCLINE_MODEL.
    set -l model claude-sonnet-4-6
    set -q CCLINE_MODEL; and test -n "$CCLINE_MODEL"; and set model $CCLINE_MODEL
    claude -p \
        --system-prompt "$sys" \
        --tools "" \
        --setting-sources "" \
        --strict-mcp-config \
        --output-format text \
        --model "$model" \
        "$prompt"
end

# Ask via the codex CLI. codex exec has no system-prompt flag, so the formatting
# instructions are prepended to the prompt. read-only sandbox so it can't change
# anything while answering; -o captures just the final message.
function ccline_ask_codex
    set -l prompt $argv[1]
    set -l sys $argv[2]
    set -l model_args
    set -q CCLINE_MODEL; and test -n "$CCLINE_MODEL"; and set model_args --model $CCLINE_MODEL
    set -l out (mktemp)
    printf '%s\n\nQuestion: %s\n' "$sys" "$prompt" \
        | codex exec \
            --sandbox read-only \
            --skip-git-repo-check \
            --color never \
            $model_args \
            -o "$out" - >/dev/null 2>&1
    set -l rc $status
    cat "$out" 2>/dev/null
    rm -f "$out"
    return $rc
end

# Read an answer on stdin, print the lines that live inside ```bash / ```sh /
# ```shell fenced blocks (one line per command, order preserved).
function ccline_extract_commands
    awk '
        /^[[:space:]]*```/ {
            if (infence) { infence = 0; next }
            info = $0
            sub(/^[[:space:]]*```/, "", info)
            gsub(/[[:space:]]/, "", info)
            info = tolower(info)
            if (info == "bash" || info == "sh" || info == "shell") infence = 1
            next
        }
        infence { print }
    '
end

# Keep only runnable lines: drop blank lines and comment-only lines.
function ccline_runnable_lines
    grep -vE '^[[:space:]]*($|#)'; or true
end

# Render Markdown on stdin to ANSI for terminal display. Uses glow if present;
# otherwise a built-in perl renderer (no extra dependency).
function ccline_render
    if command -q glow
        if glow - 2>/dev/null
            return 0
        end
    end
    perl -e '
my $in = 0;
my ($B,$D,$C,$G,$I,$R) = ("\e[1m","\e[2m","\e[36m","\e[32m","\e[3m","\e[0m");
while (my $l = <STDIN>) {
  chomp $l;
  if ($l =~ /^\s*```/) { $in = !$in; next; }   # hide fence markers
  if ($in)             { print "${G}    $l${R}\n"; next; }   # code: green, indented
  if ($l =~ /^(#{1,6})\s+(.*)/) { print "${B}$2${R}\n"; next; }   # heading
  $l =~ s/^(\s*)[-*]\s+/$1• /;                 # bullets
  $l =~ s/`([^`]+)`/${C}$1${R}/g;              # inline code
  $l =~ s/\*\*([^*]+)\*\*/${B}$1${R}/g;        # **bold**
  $l =~ s/(?<!\*)\*([^*]+)\*(?!\*)/${I}$1${R}/g;  # *italic*
  print "$l\n";
}
'
end

# A "thinking" animation shown while we wait for the LLM. Cycles a braille
# spinner next to a label, redrawn in place at ~10fps, dimmed, cursor hidden.
# Draws ONLY to /dev/tty — never stdout/stderr — because the caller captures
# the answer via command substitution and any stray bytes would corrupt it.
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

# True when we have an interactive terminal we can read keystrokes from.
function ccline_can_interact
    isatty stdout; or return 1
    test -r /dev/tty; or return 1
    return 0
end

# Arrow-key menu. Args are the labels. Draws to /dev/tty and echoes the chosen
# 0-based index to stdout. ↑/↓ (or k/j) move, Enter confirms, q cancels (which
# selects the last item — callers make that "Cancel").
function ccline_menu
    set -l items $argv
    set -l n (count $items)
    set -l sel 1
    set -l ESC \e
    set -l UP $ESC"[A"
    set -l DOWN $ESC"[B"
    set -l tty /dev/tty

    set -l saved (stty -g <$tty 2>/dev/null)
    stty -echo -icanon min 1 time 0 <$tty 2>/dev/null    # raw, no echo
    printf '%s[?25l' $ESC >$tty                          # hide cursor

    set -g __ccline_menu_saved $saved
    function __ccline_menu_int --on-signal INT --inherit-variable __ccline_menu_saved
        stty $__ccline_menu_saved </dev/tty 2>/dev/null
        printf '\e[?25h' >/dev/tty 2>/dev/null
        functions -e __ccline_menu_int
    end

    set -l first 1
    while true
        if test $first -eq 1
            set first 0
        else
            printf '%s[%dA' $ESC $n >$tty               # cursor up n lines
        end
        for i in (seq 1 $n)
            if test $i -eq $sel
                printf '%s[2K%s[7m ❯ %s %s[0m\n' $ESC $ESC $items[$i] $ESC >$tty
            else
                printf '%s[2K   %s\n' $ESC $items[$i] >$tty
            end
        end

        set -l key
        read --nchars 1 --local --raw key <$tty
        or break

        if test "$key" = $ESC
            set -l rest
            read --nchars 2 --local --raw rest <$tty
            set key "$key$rest"
        end

        if test "$key" = $UP; or test "$key" = k; or test "$key" = K
            set sel (math "(($sel - 2 + $n) % $n) + 1")
        else if test "$key" = $DOWN; or test "$key" = j; or test "$key" = J
            set sel (math "($sel % $n) + 1")
        else if test -z "$key"; or test "$key" = \n; or test "$key" = \r
            break                                       # Enter
        else if test "$key" = q; or test "$key" = Q
            set sel $n                                  # cancel → last item
            break
        end
    end

    printf '%s[?25h' $ESC >$tty
    stty $saved <$tty 2>/dev/null
    functions -q __ccline_menu_int; and functions -e __ccline_menu_int
    set -e __ccline_menu_saved
    echo (math "$sel - 1")
end

function ccline
    if test (count $argv) -eq 0
        echo "usage: ccline <your thought>" >&2
        return 2
    end

    set -l backend (ccline_backend)
    if test -z "$backend"
        echo "ccline: no LLM CLI found — install 'claude' (preferred) or 'codex':" >&2
        echo "  Claude Code: https://claude.com/claude-code" >&2
        echo "  Codex:       https://github.com/openai/codex" >&2
        return 127
    end

    set -l prompt (string join ' ' $argv)
    set -l sys (ccline_system_prompt | string collect)

    set -l spin_pid
    if isatty stdout
        ccline_spinner &
        set spin_pid $last_pid
        disown $spin_pid 2>/dev/null
    end

    set -l answer (ccline_ask_$backend "$prompt" "$sys" | string collect)
    set -l rc $pipestatus[1]

    if test -n "$spin_pid"
        kill $spin_pid 2>/dev/null
        printf '\r\e[K\e[?25h' >/dev/tty 2>/dev/null
        set spin_pid
    end

    if test $rc -ne 0
        echo "ccline: $backend exited with status $rc" >&2
        return $rc
    end

    set -l trimmed (string trim -- "$answer" | string collect)
    if test -z "$trimmed"
        echo "ccline: empty response from $backend" >&2
        return 1
    end

    if isatty stdout
        printf '%s\n' "$answer" | ccline_render
    else
        printf '%s\n' "$answer"
    end

    set -l runnable (printf '%s\n' "$answer" | ccline_extract_commands | ccline_runnable_lines)
    test (count $runnable) -eq 0; and return 0

    set -l cmds
    for line in $runnable
        test -n "$line"; and set cmds $cmds $line
    end
    set -l n (count $cmds)
    test $n -eq 0; and return 0

    set -l to_run

    if ccline_can_interact
        set -l labels $cmds
        set -l all_idx 0
        if test $n -gt 1
            set labels $labels "➤ Run all of them"
            set all_idx (count $labels)
        end
        set labels $labels "✗ Cancel"
        set -l cancel_idx (count $labels)

        echo
        echo "Commands found — ↑/↓ to choose, Enter to run, q to cancel:"
        set -l choice0 (ccline_menu $labels)
        set -l choice (math "$choice0 + 1")

        if test $choice -ge 1; and test $choice -ne $cancel_idx
            if test $all_idx -gt 0; and test $choice -eq $all_idx
                set to_run $cmds
            else if test $choice -le $n
                set to_run $cmds[$choice]
            end
        end
    else
        echo
        echo "Commands found:"
        for i in (seq 1 $n)
            printf '  %d. %s\n' $i $cmds[$i]
        end
        if test $n -eq 1
            printf 'Run it? [y/N] '
        else
            printf 'Run which? [1-%d, a=all, Enter=none] ' $n
        end
        set -l ans
        read --local ans
        or set ans ""
        switch $ans
            case a A
                set to_run $cmds
            case y Y
                test $n -eq 1; and set to_run $cmds[1]
            case '' n N
                # nothing
            case '*'
                if string match -qr '^[0-9]+$' -- $ans
                    if test $ans -ge 1; and test $ans -le $n
                        set to_run $cmds[$ans]
                    end
                end
        end
    end

    test (count $to_run) -eq 0; and return 0

    # Called from fish_command_not_found? Hand commands back via a global so the
    # handler can eval them in the user's live shell. Otherwise run them here.
    if set -q __ccline_handler_mode
        set -g __ccline_pending $to_run
        return 0
    end

    for line in $to_run
        printf '$ %s\n' $line
        if not eval $line
            set rc $status
            echo "ccline: command failed (exit $rc); stopping." >&2
            return $rc
        end
    end
end
