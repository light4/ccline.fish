#!/usr/bin/env bash
#
# Install ccline. Two paths:
#   • Fisher (recommended):  fisher install light4/ccline.fish
#   • This script:           ./install.sh   (local clone)
#                            curl -fsSL <raw-url>/install.sh | bash   (remote)
#
# This script copies the same files Fisher would, into ~/.config/fish/. Safe
# to re-run.

set -euo pipefail

REPO="light4/ccline.fish"
REF="${CCLINE_REF:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${REF}"

FISH_FUNCTIONS="${HOME}/.config/fish/functions"
FISH_CONFD="${HOME}/.config/fish/conf.d"

# Find source files: prefer a local clone; otherwise download from GitHub.
SRC_DIR=""
if [ -n "${BASH_SOURCE:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  maybe="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "${maybe}/functions/ccline.fish" ] && [ -f "${maybe}/conf.d/ccline.fish" ]; then
    SRC_DIR="$maybe"
  fi
fi

cleanup=""
if [ -z "$SRC_DIR" ]; then
  echo "Downloading ccline from ${REPO}…"
  SRC_DIR="$(mktemp -d)"
  cleanup="$SRC_DIR"
  mkdir -p "${SRC_DIR}/functions" "${SRC_DIR}/conf.d"
  for f in functions/ccline.fish conf.d/ccline.fish; do
    if ! curl -fsSL "${RAW}/${f}" -o "${SRC_DIR}/${f}"; then
      echo "ccline: failed to download ${f} from ${RAW}/${f}" >&2
      rm -rf "$cleanup"
      exit 1
    fi
  done
fi

mkdir -p "$FISH_FUNCTIONS" "$FISH_CONFD"
install -m 0644 "${SRC_DIR}/functions/ccline.fish" "${FISH_FUNCTIONS}/ccline.fish"
install -m 0644 "${SRC_DIR}/conf.d/ccline.fish" "${FISH_CONFD}/ccline.fish"
[ -n "$cleanup" ] && rm -rf "$cleanup"

echo "Installed:"
echo "  ${FISH_FUNCTIONS}/ccline.fish"
echo "  ${FISH_CONFD}/ccline.fish"

if ! command -v fish >/dev/null 2>&1; then
  echo "NOTE: 'fish' was not found on PATH. ccline targets the fish shell."
  echo "      https://fishshell.com"
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "NOTE: the 'claude' CLI was not found. ccline needs it (or 'codex'):"
  echo "      https://claude.com/claude-code"
fi

echo
echo "Done. Open a new fish session and just type a thought:"
echo "    how do I find files bigger than 100MB here"
