#!/usr/bin/env fish
#
# Install ccline. Two paths:
#   • Fisher (recommended):  fisher install light4/ccline.fish
#   • This script:           ./install.fish   (local clone)
#                            curl -fsSL <raw-url>/install.fish | source   (remote)
#
# This script copies the same files Fisher would, into ~/.config/fish/. Safe
# to re-run.

set REPO light4/ccline.fish
set REF (set -q CCLINE_REF; and echo $CCLINE_REF; or echo main)
set RAW "https://raw.githubusercontent.com/$REPO/$REF"

set FISH_FUNCTIONS $HOME/.config/fish/functions
set FISH_CONFD $HOME/.config/fish/conf.d

# Find source files: prefer a local clone; otherwise download from GitHub.
set SRC_DIR ""
set -l self (status filename)
if test -n "$self"
    set -l maybe (cd (dirname $self); and pwd)
    if test -f "$maybe/functions/ccline.fish"; and test -f "$maybe/conf.d/ccline.fish"
        set SRC_DIR $maybe
    end
end

set cleanup ""
if test -z "$SRC_DIR"
    echo "Downloading ccline from $REPO…"
    set SRC_DIR (mktemp -d)
    set cleanup $SRC_DIR
    mkdir -p $SRC_DIR/functions $SRC_DIR/conf.d
    for f in functions/ccline.fish conf.d/ccline.fish
        if not curl -fsSL "$RAW/$f" -o "$SRC_DIR/$f"
            echo "ccline: failed to download $f from $RAW/$f" >&2
            rm -rf $cleanup
            exit 1
        end
    end
end

mkdir -p $FISH_FUNCTIONS $FISH_CONFD
install -m 0644 $SRC_DIR/functions/ccline.fish $FISH_FUNCTIONS/ccline.fish
install -m 0644 $SRC_DIR/conf.d/ccline.fish $FISH_CONFD/ccline.fish
test -n "$cleanup"; and rm -rf $cleanup

echo Installed:
echo "  $FISH_FUNCTIONS/ccline.fish"
echo "  $FISH_CONFD/ccline.fish"

if not command -q claude
    echo "NOTE: the 'claude' CLI was not found. ccline needs it (or 'codex'):"
    echo "      https://claude.com/claude-code"
end

echo
echo "Done. Open a new fish session, or run:"
echo "    source $FISH_CONFD/ccline.fish"
echo "and just type a thought:"
echo "    how do I find files bigger than 100MB here"
