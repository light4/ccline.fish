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
    # Don't clobber a user override already in place.
    if not bind enter 2>/dev/null | string match -q '*__ccline_smart_enter*'
        bind enter __ccline_smart_enter
    end
end
