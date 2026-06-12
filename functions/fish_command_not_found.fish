# ccline — fish_command_not_found handler.
#
# Autoloaded by fish. Lives in functions/ (not conf.d/) so it beats fish's
# default handler in /opt/homebrew/share/fish/functions/fish_command_not_found.fish:
# fish's autoload always picks the user's $fish_function_path entry first, but
# conf.d-defined functions get clobbered when the default file autoloads
# itself on first invocation.
#
# When you type something that isn't a real command, fish calls this. A
# single unknown word is a normal typo (the usual "Unknown command"). Two or
# more words are treated as a thought and routed to the `ccline` function
# (defined lazily in functions/ccline.fish).
#
# ccline writes the user's chosen commands into the global $__ccline_pending
# list; this handler then evals each one — so cd, set, abbreviations, and
# history all work and persist as if you'd typed them yourself.

function fish_command_not_found
    if test (count $argv) -ge 2; and functions -q ccline
        set -g __ccline_handler_mode 1
        set -g __ccline_pending
        ccline $argv
        set -l rc $status
        set -e __ccline_handler_mode

        if set -q __ccline_pending; and test (count $__ccline_pending) -gt 0
            for line in $__ccline_pending
                test -n "$line"; or continue
                printf '$ %s\n' $line
                if not eval $line
                    set rc $status
                    break
                end
            end
        end
        set -e __ccline_pending
        return $rc
    end

    printf 'fish: Unknown command: %s\n' (string escape -- $argv[1]) >&2
    return 127
end
