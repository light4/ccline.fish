# Install the ccline Enter binding at shell startup.
#
# fish_command_not_found is unavoidable for 2+-word "thoughts" unless we
# intercept Enter before fish parses the line — fish itself always prints
# its "fish: <cmd>\n ^~^" caret context after the handler runs, regardless
# of the handler's return code (it's hardcoded in fish's C++).
#
# So instead of relying on the handler alone, we bind Enter to
# __ccline_smart_enter (autoloaded from functions/) which routes thoughts
# to ccline directly and leaves real commands alone.
#
# Interactive only — bindings have no effect in script/pipe contexts.

if status --is-interactive
    # Install our binding in a given key-binding mode iff no user override
    # is already there. fish's `bind <key>` lists ALL bindings for that key
    # (preset first, then any user binding); we only consider a non-preset
    # entry as a "user override". Re-installing over ourselves is fine.
    function __ccline_install_bind
        set -l user_bind (bind $argv enter 2>/dev/null | string match -rv -- '^bind --preset' | string collect)
        if test -z "$user_bind"; or string match -q '*__ccline_smart_enter*' -- $user_bind
            bind $argv enter __ccline_smart_enter 2>/dev/null
        end
    end

    # Default keymap (emacs / fish_default_key_bindings).
    __ccline_install_bind

    # Vi-mode insert mode. Without this, vi users sit in insert mode where
    # Enter is the preset `execute` and our binding never fires, so fish
    # parses the thought and the caret reappears.
    __ccline_install_bind -M insert

    functions -e __ccline_install_bind
end
