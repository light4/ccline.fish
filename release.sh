#!/usr/bin/env bash
#
# Cut a new ccline release.
#
#   ./release.sh vX.Y.Z ["release notes..."]
#
# Steps, in order:
#   1. validate the version and preconditions (clean tree, tag is new, tests pass)
#   2. bump the pinned version in install.sh and README.md
#   3. commit and push main
#   4. create and push the git tag
#   5. create the GitHub release (with the pinned install one-liner)

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

NEW="${1:-}"
if [ -z "$NEW" ]; then
  echo "usage: ./release.sh vX.Y.Z [\"release notes...\"]" >&2
  exit 2
fi
case "$NEW" in v*) ;; *) NEW="v$NEW" ;; esac
if ! echo "$NEW" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "release: version must look like vX.Y.Z (got '$NEW')" >&2
  exit 2
fi

command -v gh >/dev/null || { echo "release: gh CLI not found" >&2; exit 1; }

# Current pinned version = first vX.Y.Z in install.sh (the REF default).
CUR="$(grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' install.sh | head -1 || true)"
if [ -n "$CUR" ] && [ "$CUR" = "$NEW" ]; then
  echo "release: $NEW is already the current version" >&2; exit 1
fi

if [ -n "$CUR" ]; then
  echo "Releasing ${CUR} -> ${NEW}"
else
  echo "Releasing ${NEW} (no prior version pinned in install.sh)"
fi

# Preconditions.
[ -z "$(git status --porcelain)" ] || { echo "release: working tree not clean" >&2; exit 1; }
if git rev-parse "$NEW" >/dev/null 2>&1; then
  echo "release: tag $NEW already exists" >&2; exit 1
fi
echo "Running tests…"
fish tests/test_ccline.fish >/dev/null || { echo "release: tests failed" >&2; exit 1; }

# Bump the pinned version (portable in-place edit via perl).
if [ -n "$CUR" ]; then
  perl -i -pe "s/\Q${CUR}\E/${NEW}/g" install.sh README.md
else
  # First release: pin install.sh's REF default to $NEW and refresh the README
  # one-liner URL to point at $NEW instead of "main".
  perl -i -pe 's{(CCLINE_REF:-)main}{$1'"$NEW"'}' install.sh
  perl -i -pe 's{(/ccline\.fish/)main(/install\.sh)}{$1'"$NEW"'$2}' README.md
fi

# Commit + push main.
git add -A
git commit -q -m "Release ${NEW}"
git push -q origin main

# Tag + push.
git tag -a "$NEW" -m "ccline ${NEW}"
git push -q origin "$NEW"

# GitHub release.
shift || true
NOTES="${*:-Release ${NEW}.}"
gh release create "$NEW" --title "ccline ${NEW}" --notes "${NOTES}

## Install
\`\`\`sh
curl -fsSL https://raw.githubusercontent.com/jianshuo/ccline.fish/${NEW}/install.sh | bash
\`\`\`"

echo "Released ${NEW}: https://github.com/jianshuo/ccline.fish/releases/tag/${NEW}"
