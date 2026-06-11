# ccline — fish integration.
#
# Drop this in ~/.config/fish/conf.d/ (or install.sh does it for you). Fish
# auto-loads everything in conf.d/ on startup, so no edits to config.fish are
# needed.
#
# When you type something that isn't a real command, fish calls
# fish_command_not_found. A single unknown word is treated as a normal typo
# (the usual "Unknown command"). Two or more words are treated as a thought and
# routed to the `ccline` helper, which asks Claude.
#
# The helper renders the answer and shows the command menu, but it does NOT
# run the chosen command itself. It writes the selection to $CCLINE_RUN_FILE
# and this handler evals it — so the command runs in YOUR live shell, where
# cd, set, abbreviations, and history all work as expected.

function fish_command_not_found
    # Two or more words AND the helper is actually installed → ask Claude.
    if test (count $argv) -ge 2; and command -q ccline
        set -l runfile (mktemp "$TMPDIR"/ccline.XXXXXX 2>/dev/null; or mktemp /tmp/ccline.XXXXXX)
        if test -z "$runfile"
            command ccline $argv
            return $status
        end

        CCLINE_RUN_FILE=$runfile command ccline $argv
        set -l rc $status

        if test -s "$runfile"
            # Run the chosen command(s) in this interactive shell.
            while read -l line
                test -n "$line"; or continue
                printf '%s %s\n' \$ $line
                eval $line
                or begin
                    set rc $status
                    break
                end
            end <"$runfile"
        end

        rm -f "$runfile"
        return $rc
    end

    # Single token, or helper not installed: behave like a normal shell.
    printf 'fish: Unknown command: %s\n' $argv[1] >&2
    return 127
end
