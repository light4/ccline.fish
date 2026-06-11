#!/usr/bin/env bash
#
# Install ccline (fish edition). Works two ways:
#   • from a local clone:   ./install.sh
#   • remotely:             curl -fsSL <raw-url>/install.sh | bash
#
# Idempotent — safe to re-run. Drops ccline into ~/.local/bin and
# ccline.fish into ~/.config/fish/conf.d/ (auto-loaded by fish; no config
# edits needed).

set -euo pipefail

# Pinned to a release tag so the install command is stable across future
# changes. Override with CCLINE_REF=main (or another tag) to install elsewhere.
REPO="jianshuo/ccline.fish"
REF="${CCLINE_REF:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${REF}"

BIN_DIR="${HOME}/.local/bin"
FISH_CONFD="${HOME}/.config/fish/conf.d"

# Find source files: prefer a local clone; otherwise download from GitHub.
SRC_DIR=""
if [ -n "${BASH_SOURCE:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  maybe="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "${maybe}/ccline" ] && [ -f "${maybe}/ccline.fish" ]; then
    SRC_DIR="$maybe"
  fi
fi

cleanup=""
if [ -z "$SRC_DIR" ]; then
  echo "Downloading ccline from ${REPO}…"
  SRC_DIR="$(mktemp -d)"
  cleanup="$SRC_DIR"
  for f in ccline ccline.fish; do
    if ! curl -fsSL "${RAW}/${f}" -o "${SRC_DIR}/${f}"; then
      echo "ccline: failed to download ${f} from ${RAW}/${f}" >&2
      rm -rf "$cleanup"
      exit 1
    fi
  done
fi

mkdir -p "$BIN_DIR" "$FISH_CONFD"
install -m 0755 "${SRC_DIR}/ccline" "${BIN_DIR}/ccline"
install -m 0644 "${SRC_DIR}/ccline.fish" "${FISH_CONFD}/ccline.fish"
[ -n "$cleanup" ] && rm -rf "$cleanup"

echo "Installed:"
echo "  ${BIN_DIR}/ccline"
echo "  ${FISH_CONFD}/ccline.fish"

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *) echo "NOTE: ${BIN_DIR} is not on your PATH. Add it to ~/.config/fish/config.fish:"
     echo "    fish_add_path -U ${BIN_DIR}" ;;
esac

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
