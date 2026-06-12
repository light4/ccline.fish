#!/usr/bin/env fish
# Tests for ccline. Run: fish tests/test_ccline.fish

set HERE (cd (dirname (status filename)); and pwd)
set ROOT (dirname $HERE)

# Source the function library directly so the helpers and the public `ccline`
# function are defined in this shell (fish would otherwise lazy-autoload them).
source $ROOT/functions/ccline.fish

set -g pass 0
set -g fail 0

function check
    set -l desc $argv[1]
    set -l expected $argv[2]
    set -l actual $argv[3]
    if test "$expected" = "$actual"
        set -g pass (math $pass + 1)
    else
        set -g fail (math $fail + 1)
        printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$desc" "$expected" "$actual"
    end
end

# --- extraction: a single bash block ---
set ans 'Here you go:
```bash
find . -size +100M
```
That lists big files.'
set -l got (printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines | string collect)
check "single bash block" "find . -size +100M" "$got"

# --- extraction: sh and shell info strings, multiple blocks, order preserved ---
set ans '```sh
echo one
```
prose
```SHELL
echo two
```'
set -l got (printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines | string collect)
check "sh + SHELL blocks, order" 'echo one
echo two' "$got"

# --- extraction: fish fence ---
set ans 'Here:
```fish
set -x FOO bar
```'
set -l got (printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines | string collect)
check "fish block recognized" "set -x FOO bar" "$got"

# --- non-shell blocks are ignored ---
set ans '```python
print("hi")
```
```
plain fence, not runnable
```'
set -l got (printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines | string collect)
check "ignore python and bare fences" "" "$got"

# --- comment-only and blank lines are dropped from runnable set ---
set ans '```bash
# just a comment
ls -la

du -sh .
```'
set -l got (printf '%s\n' "$ans" | ccline_extract_commands | ccline_runnable_lines | string collect)
check "drop comments and blanks" 'ls -la
du -sh .' "$got"

# --- no fenced blocks at all ---
set -l got (printf 'just prose, no code.\n' | ccline_extract_commands | ccline_runnable_lines | string collect)
check "no blocks" "" "$got"

# --- render: hides fence markers, keeps code text ---
set -l rendered (printf '## Title\n```bash\nls -la\n```\n' | ccline_render | string collect)
if string match -q '*```*' -- $rendered
    check "render hides fences" "no-fence" "has-fence"
else
    check "render hides fences" "no-fence" "no-fence"
end
if string match -q '*ls -la*' -- $rendered
    check "render keeps code text" "yes" "yes"
else
    check "render keeps code text" "yes" "no"
end

# --- end-to-end with a stubbed claude: no commands => prints answer, rc 0 ---
set STUB (mktemp -d)
echo '#!/usr/bin/env bash
echo "Paris is the capital of France."' >$STUB/claude
chmod +x $STUB/claude

set -l saved_path $PATH
set PATH $STUB $PATH
set -l out (ccline what is the capital of France | string collect)
set -l rc $status
check "stub claude prints answer (rc)" "0" "$rc"
check "stub claude prints answer (text)" "Paris is the capital of France." "$out"

# spinner must NOT leak into captured (non-tty) output
if string match -q '*thinking*' -- $out
    check "no spinner leak (label)" "clean" "leaked"
else
    check "no spinner leak (label)" "clean" "clean"
end
if string match -q '*⠋*' -- $out; or string match -q '*⠙*' -- $out
    check "no spinner leak (frames)" "clean" "leaked"
else
    check "no spinner leak (frames)" "clean" "clean"
end

# --- handler mode: ccline returns selection via $__ccline_pending, does NOT exec ---
set sentinel $STUB/sentinel-created
echo "#!/usr/bin/env bash
echo \"\`\`\`bash\"
echo \"touch $sentinel\"
echo \"\`\`\`\"" >$STUB/claude
chmod +x $STUB/claude
set -g __ccline_handler_mode 1
set -g __ccline_pending
printf 'y\n' | ccline do a thing >/dev/null
set -e __ccline_handler_mode
if test -e $sentinel
    check "handler mode: command NOT executed inline" "no" "yes"
else
    check "handler mode: command NOT executed inline" "no" "no"
end
check "handler mode: pending list populated" "touch $sentinel" (string join \n $__ccline_pending | string collect)
set -e __ccline_pending
rm -f $sentinel

# --- usage when no args ---
ccline >/dev/null 2>&1
check "no args => rc 2" "2" "$status"

# --- no LLM CLI at all => rc 127 ---
set PATH /nonexistent-only
ccline hello there >/dev/null 2>&1
set -l rc $status
set PATH $saved_path
check "no LLM CLI => rc 127" "127" "$rc"

# --- backend detection: claude precedence, codex fallback, override, none ---
set BOTH (mktemp -d)
set ONLYCODEX (mktemp -d)
printf '#!/usr/bin/env bash\necho CLAUDE_REPLY\n' >$BOTH/claude
echo '#!/usr/bin/env bash
out=""; while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
cat >/dev/null
[ -n "$out" ] && printf "CODEX_REPLY\n" > "$out"' >$BOTH/codex
cp $BOTH/codex $ONLYCODEX/codex
chmod +x $BOTH/claude $BOTH/codex $ONLYCODEX/codex

set PATH $BOTH /usr/bin /bin
check "backend: claude precedence" "claude" (ccline_backend)

set PATH $ONLYCODEX /usr/bin /bin
check "backend: codex fallback" "codex" (ccline_backend)

set PATH $BOTH /usr/bin /bin
set -x CCLINE_BACKEND codex
check "backend: override to codex" "codex" (ccline_backend)
set -e CCLINE_BACKEND

set PATH /nonexistent
check "backend: none found" "" (ccline_backend)

# end-to-end through the codex fallback (no claude on PATH)
set PATH $ONLYCODEX /usr/bin /bin
set -l out (ccline ask codex something </dev/null | string collect)
check "codex e2e: answer used" "CODEX_REPLY" (printf '%s' "$out" | grep -o CODEX_REPLY | head -1 | string collect)

set PATH $saved_path
rm -rf $BOTH $ONLYCODEX $STUB

echo
echo "passed: $pass, failed: $fail"
test $fail -eq 0
