#!/usr/bin/env fish
#
# Install ccline. Two paths:
#   • Fisher (recommended):  fisher install light4/ccline.fish
#   • This script:           ./install.fish   (local clone)
#                            curl -fsSL <raw-url>/install.fish | source   (remote)
#
# Drops files into ~/.config/fish/{functions,conf.d}/. Safe to re-run.

set REPO light4/ccline.fish
set REF (set -q CCLINE_REF; and echo $CCLINE_REF; or echo main)
set RAW "https://raw.githubusercontent.com/$REPO/$REF"

set FISH_FUNCTIONS $HOME/.config/fish/functions
set FISH_CONFD $HOME/.config/fish/conf.d

set FILES \
    functions/ccline.fish \
    functions/ccline_spinner.fish \
    functions/__ccline_smart_enter.fish \
    functions/fish_command_not_found.fish \
    conf.d/ccline.fish

# Find source files: prefer a local clone; otherwise download from GitHub.
set SRC_DIR ""
set -l self (status filename)
if test -n "$self"
    set -l maybe (cd (dirname $self); and pwd)
    set -l ok 1
    for f in $FILES
        test -f "$maybe/$f"; or set ok 0
    end
    test $ok -eq 1; and set SRC_DIR $maybe
end

set cleanup ""
if test -z "$SRC_DIR"
    echo "Downloading ccline from $REPO…"
    set SRC_DIR (mktemp -d)
    set cleanup $SRC_DIR
    mkdir -p $SRC_DIR/functions $SRC_DIR/conf.d
    for f in $FILES
        if not curl -fsSL "$RAW/$f" -o "$SRC_DIR/$f"
            echo "ccline: failed to download $f from $RAW/$f" >&2
            rm -rf $cleanup
            exit 1
        end
    end
end

mkdir -p $FISH_FUNCTIONS $FISH_CONFD
for f in $FILES
    set -l base (basename $f)
    if string match -q 'functions/*' -- $f
        install -m 0644 $SRC_DIR/$f $FISH_FUNCTIONS/$base
    else
        install -m 0644 $SRC_DIR/$f $FISH_CONFD/$base
    end
end
test -n "$cleanup"; and rm -rf $cleanup

echo Installed:
for f in $FILES
    set -l base (basename $f)
    if string match -q 'functions/*' -- $f
        echo "  $FISH_FUNCTIONS/$base"
    else
        echo "  $FISH_CONFD/$base"
    end
end

if not command -q claude
    echo "NOTE: the 'claude' CLI was not found. ccline needs it (or 'codex'):"
    echo "      https://claude.com/claude-code"
end

echo
echo "Done. Open a new fish session, then type a thought:"
echo "    how do I find files bigger than 100MB here"
