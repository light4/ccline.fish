#!/usr/bin/env bash
# Tests for ccline. Run: bash tests/test_ccline.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

# shellcheck source=/dev/null
source "${ROOT}/ccline"   # sourcing does NOT run main (guarded by BASH_SOURCE check)

pass=0 fail=0
check() { # desc, expected, actual
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$1" "$2" "$3"
  fi
}

# --- extraction: a single bash block ---
ans="Here you go:
\`\`\`bash
find . -size +100M
\`\`\`
That lists big files."
got="$(printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines)"
check "single bash block" "find . -size +100M" "$got"

# --- extraction: sh and shell info strings, multiple blocks, order preserved ---
ans="\`\`\`sh
echo one
\`\`\`
prose
\`\`\`SHELL
echo two
\`\`\`"
got="$(printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines)"
check "sh + SHELL blocks, order" $'echo one\necho two' "$got"

# --- non-shell blocks are ignored ---
ans="\`\`\`python
print('hi')
\`\`\`
\`\`\`
plain fence, not runnable
\`\`\`"
got="$(printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines)"
check "ignore python and bare fences" "" "$got"

# --- comment-only and blank lines are dropped from runnable set ---
ans="\`\`\`bash
# just a comment
ls -la

du -sh .
\`\`\`"
got="$(printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines)"
check "drop comments and blanks" $'ls -la\ndu -sh .' "$got"

# --- no fenced blocks at all ---
got="$(printf 'just prose, no code.\n' | ccline_extract_commands | ccline_runnable_lines)"
check "no blocks" "" "$got"

# --- render: hides fence markers, keeps code text, emits ANSI for heading ---
rendered="$(printf '## Title\n\`\`\`bash\nls -la\n\`\`\`\n' | ccline_render)"
case "$rendered" in *'```'*) check "render hides fences" "no-fence" "has-fence" ;; *) check "render hides fences" "no-fence" "no-fence" ;; esac
case "$rendered" in *'ls -la'*) check "render keeps code text" "yes" "yes" ;; *) check "render keeps code text" "yes" "no" ;; esac
case "$rendered" in *$'\e['*) check "render emits ANSI" "yes" "yes" ;; *) check "render emits ANSI" "yes" "no" ;; esac

# --- end-to-end with a stubbed claude: no commands => prints answer, rc 0 ---
STUB="$(mktemp -d)"
cat > "${STUB}/claude" <<'STUBEOF'
#!/usr/bin/env bash
echo "Paris is the capital of France."
STUBEOF
chmod +x "${STUB}/claude"
out="$(PATH="${STUB}:${PATH}" ccline_main what is the capital of France)"
rc=$?
check "stub claude prints answer (rc)" "0" "$rc"
check "stub claude prints answer (text)" "Paris is the capital of France." "$out"

# --- CCLINE_RUN_FILE: selection is written to the file, NOT executed here ---
sentinel="${STUB}/sentinel-created"
cat > "${STUB}/claude" <<STUBEOF
#!/usr/bin/env bash
printf '\`\`\`bash\ntouch ${sentinel}\n\`\`\`\n'
STUBEOF
chmod +x "${STUB}/claude"
runfile="$(mktemp)"
printf 'y\n' | PATH="${STUB}:${PATH}" CCLINE_RUN_FILE="$runfile" ccline_main do a thing >/dev/null
check "run-file: command NOT executed inline" "no" "$([ -e "$sentinel" ] && echo yes || echo no)"
check "run-file: contains the command" "touch ${sentinel}" "$(cat "$runfile")"
rm -f "$runfile" "$sentinel"

# --- usage when no args ---
PATH="${STUB}:${PATH}" ccline_main >/dev/null 2>&1
check "no args => rc 2" "2" "$?"

# --- no LLM CLI at all => rc 127 ---
( PATH="/nonexistent-only"; ccline_main hello there >/dev/null 2>&1 )
check "no LLM CLI => rc 127" "127" "$?"

# --- backend detection: claude precedence, codex fallback, override, none ---
BOTH="$(mktemp -d)"; ONLYCODEX="$(mktemp -d)"
printf '#!/usr/bin/env bash\necho CLAUDE_REPLY\n' > "${BOTH}/claude"
cat > "${BOTH}/codex" <<'CX'
#!/usr/bin/env bash
out=""; while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
cat >/dev/null   # consume the prompt on stdin
[ -n "$out" ] && printf 'CODEX_REPLY\n' > "$out"
CX
cp "${BOTH}/codex" "${ONLYCODEX}/codex"
chmod +x "${BOTH}/claude" "${BOTH}/codex" "${ONLYCODEX}/codex"

check "backend: claude precedence"  "claude" "$(PATH="${BOTH}:/usr/bin:/bin" ccline_backend)"
check "backend: codex fallback"     "codex"  "$(PATH="${ONLYCODEX}:/usr/bin:/bin" ccline_backend)"
check "backend: override to codex"  "codex"  "$(PATH="${BOTH}:/usr/bin:/bin" CCLINE_BACKEND=codex ccline_backend)"
check "backend: none found"         ""       "$(PATH=/nonexistent ccline_backend)"

# end-to-end through the codex fallback (no claude on PATH)
out="$(PATH="${ONLYCODEX}:/usr/bin:/bin" ccline_main ask codex something < /dev/null)"
check "codex e2e: answer used" "CODEX_REPLY" "$(printf '%s' "$out" | grep -o CODEX_REPLY | head -1)"
rm -rf "$BOTH" "$ONLYCODEX"

rm -rf "$STUB"

echo
echo "passed: ${pass}, failed: ${fail}"
[ "$fail" -eq 0 ]
