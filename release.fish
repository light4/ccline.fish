#!/usr/bin/env fish
#
# Cut a new ccline release.
#
#   ./release.fish vX.Y.Z ["release notes..."]
#
# Steps, in order:
#   1. validate the version and preconditions (clean tree, tag is new, tests pass)
#   2. bump the pinned version in install.fish and README.md
#   3. commit and push main
#   4. create and push the git tag
#   5. create the GitHub release (with the pinned install one-liner)

cd (dirname (status filename)); or exit 1

set NEW $argv[1]
if test -z "$NEW"
    echo "usage: ./release.fish vX.Y.Z [\"release notes...\"]" >&2
    exit 2
end
string match -q 'v*' -- $NEW; or set NEW v$NEW
if not string match -qr '^v[0-9]+\.[0-9]+\.[0-9]+$' -- $NEW
    echo "release: version must look like vX.Y.Z (got '$NEW')" >&2
    exit 2
end

command -q gh; or begin
    echo "release: gh CLI not found" >&2
    exit 1
end

# Current pinned version = first vX.Y.Z in install.fish (the REF default).
set CUR (grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' install.fish | head -1)
if test -n "$CUR"; and test "$CUR" = "$NEW"
    echo "release: $NEW is already the current version" >&2
    exit 1
end

if test -n "$CUR"
    echo "Releasing $CUR -> $NEW"
else
    echo "Releasing $NEW (no prior version pinned in install.fish)"
end

# Preconditions.
# Note: `test -n (cmd | string collect)` does NOT work — when cmd produces no
# output, string collect emits zero arguments and `test -n` (zero-arg form)
# returns true. Count the lines instead.
if test (git status --porcelain | count) -gt 0
    echo "release: working tree not clean" >&2
    exit 1
end
if git rev-parse "$NEW" >/dev/null 2>&1
    echo "release: tag $NEW already exists" >&2
    exit 1
end
echo "Running tests…"
if not fish tests/test_ccline.fish >/dev/null
    echo "release: tests failed" >&2
    exit 1
end

# Bump the pinned version (portable in-place edit via perl).
if test -n "$CUR"
    perl -i -pe "s/\Q$CUR\E/$NEW/g" install.fish README.md
else
    # First release: pin install.fish's REF default to $NEW and refresh the
    # README one-liner URL to point at $NEW instead of "main".
    perl -i -pe 's{(or echo )main\)}{$1'"$NEW"'\)}' install.fish
    perl -i -pe 's{(/ccline\.fish/)main(/install\.fish)}{$1'"$NEW"'$2}' README.md
end

# Commit + push main.
git add -A
git commit -q -m "Release $NEW"
git push -q origin main

# Tag + push.
git tag -a "$NEW" -m "ccline $NEW"
git push -q origin "$NEW"

# GitHub release.
set -e argv[1]
set NOTES (string join ' ' $argv)
test -n "$NOTES"; or set NOTES "Release $NEW."
gh release create $NEW --title "ccline $NEW" --notes "$NOTES

## Install
\`\`\`fish
curl -fsSL https://raw.githubusercontent.com/light4/ccline.fish/$NEW/install.fish | source
\`\`\`"

echo "Released $NEW: https://github.com/light4/ccline.fish/releases/tag/$NEW"
