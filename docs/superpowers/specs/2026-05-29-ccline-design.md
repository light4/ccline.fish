# ccline — type a thought at your shell, get an answer

**Date:** 2026-05-29
**Status:** Approved design

## Problem

Sometimes I have a quick thought at the Mac terminal and don't want to open
Claude Code for it. I want to just *type the thought directly at the shell
prompt* — no command prefix — and get an answer. If the answer contains shell
commands I can run, I want to confirm once and run them.

## Approach

Hijack zsh's `command_not_found_handler`. When I type something that isn't a
real command, zsh passes the whole line to this function. We intercept it,
route it to the locally-installed `claude` CLI (`claude -p`, headless print
mode), print the answer, and offer to run any shell commands found in it.

This gives a **zero-prefix** experience that matches the intent exactly: type
the thought, hit enter.

### Why this backend / language

- **Backend:** reuse an installed LLM CLI — `claude` (preferred) or `codex`
  (fallback), auto-detected; override with `CCLINE_BACKEND`. No separate API
  key. claude uses a clean isolated `claude -p`; codex uses `codex exec` in a
  read-only sandbox with the system prompt prepended (codex has no
  system-prompt flag).
- **Language:** Bash/zsh. Zero dependencies, ships as a sourced shell function
  plus a helper script.

## Components

1. **`ccline.zsh`** — the shell integration. Defines
   `command_not_found_handler()`. The user sources it from `~/.zshrc`.
2. **`ccline`** — a helper script (bash) that does the real work: builds the
   prompt, calls `claude -p`, prints the answer, extracts commands, runs them
   on confirmation. Kept separate so the handler stays tiny and testable.
3. **`install.sh`** — copies `ccline` into `~/.local/bin`, copies `ccline.zsh`
   into `~/.config/ccline/`, and appends a `source` line to `~/.zshrc` (idempotent).
4. **`README.md`** — usage, install, limitations, uninstall.

## Flow

```
user types:  how do I find files bigger than 100MB here
   │
   ▼
zsh: "how" is not a command → command_not_found_handler "how" "do" ...
   │
   ├─ word count == 1 ?  → print real "zsh: command not found: <word>", return 127
   │                       (it's almost certainly a typo)
   │
   └─ word count >= 2 ?  → exec  ccline "$@"
                              │
                              ▼
                      detect backend (claude preferred, else codex) and ask it
                        claude: claude -p --system-prompt <S> --tools "" \
                          --setting-sources "" --strict-mcp-config --output-format text
                        codex:  codex exec --sandbox read-only --skip-git-repo-check \
                          --color never -o <file>  (system prompt prepended to input)
                              │
                              ▼
                      render the answer as Markdown → ANSI (raw if not a tty)
                              │
                              ▼
                      extract commands from ```bash / ```sh / ```shell fenced blocks
                              │
                  none ──────┤──────── one or more
                  (done)      │
                              ▼
                      list commands numbered
                      prompt:  "Run which? [1-N, a=all, Enter=none]"
                               (single command → "Run it? [y/N]")
                              │
                  Enter/N ───┤─────── number | a
                  (done)      │
                              ▼
                      run the selected command(s) sequentially, echoing each,
                      stopping on the first non-zero exit
```

## System prompt given to Claude

> You are a command-line assistant answering a quick question typed directly at
> a macOS zsh prompt. Be concise — a few sentences at most. If your answer
> involves shell commands the user can run, put each runnable command in its own
> fenced ```bash code block. Never put example output, file contents, or
> non-runnable snippets in a bash/sh/shell block. Prefer commands that are safe
> and non-destructive; if a command is destructive, say so plainly.

## Command extraction

- Scan the answer for fenced blocks whose info string is `bash`, `sh`, or
  `shell` (case-insensitive).
- Each non-empty, non-comment line inside such a block is one runnable command,
  preserving order across blocks.
- Comment-only lines (starting with `#`) are kept for display context but are
  harmless to run.

## Rendering

- The answer is Markdown. For terminal display it is rendered to ANSI: headings
  and `**bold**` bolded, `*italic*` italicized, `` `inline code` `` and fenced
  code colorized, `- `/`* ` bullets shown as `•`, fence markers hidden.
- Uses `glow` if installed (best quality), otherwise a built-in `perl` renderer
  (no extra dependency).
- Rendering is applied only when stdout is a terminal (`[ -t 1 ]`); piped or
  redirected output is printed raw so it stays machine-parseable.
- Extraction always runs against the **raw** answer, never the rendered copy.

## Execution / selection

- Commands are collected into a list. When stdout is an interactive terminal,
  they are shown in an **arrow-key menu**: labels are each command, plus
  "➤ Run all of them" (only when >1), plus "✗ Cancel". **↑/↓** (or k/j) move the
  highlight, **Enter** confirms, **q** cancels. The terminal is put in raw,
  no-echo mode (`stty`) for the menu's duration and restored afterward; the
  cursor is hidden and restored; an `INT` trap restores both on Ctrl-C.
- When stdout is **not** a terminal (piped/redirected/CI), it falls back to a
  typed prompt: `Run which? [1-N, a=all, Enter=none]` (or `Run it? [y/N]` for a
  single command). This keeps the tool scriptable and testable.
- Default in both modes is **run nothing**.
- **Where commands run:** when invoked from the zsh handler, ccline does NOT run
  the selection itself — it writes the chosen command(s) to `$CCLINE_RUN_FILE`
  and the handler `eval`s them in the user's **live interactive shell**, so
  `cd`, `export`, aliases, functions, and history all work and persist. When
  ccline is run directly (no `$CCLINE_RUN_FILE`), it runs the selection itself
  in its own process (cd/export won't persist there).
- Run the selection in sequence; echo each prefixed with `$ ` before running.
- If a command exits non-zero, stop and report its exit code.

## Error handling

- **Single-word unknown command** → behave like a normal shell: print
  `zsh: command not found: <word>` to stderr, return 127. No LLM call.
- **`claude` CLI not on PATH** → print a one-line install hint, return 127.
- **Empty `claude` output / non-zero exit** → report it briefly; don't pretend
  to have an answer.
- **Interrupt (Ctrl-C)** during the claude call or the run prompt → abort
  cleanly, run nothing.

## Glob safety (the `?`/`*` wrinkle)

zsh expands `?` and `*` before calling the handler, and with the default
`nomatch` option a line like `how to do X?` errors with "no matches found"
before the handler runs. The integration sets, for interactive use, an
`unsetopt nomatch` (or `setopt no_nomatch`) so unmatched globs pass through as
literal text. A stray `*` that *does* match files in the current dir can still
expand; this is a documented v1 limitation.

## Known v1 limitations

- Commands triggered via the zsh handler run in the live shell and persist;
  running `ccline …` directly runs them in a subprocess where `cd`/`export`
  won't persist.
- A bare `*` in a thought may glob-expand against the current directory.
- Single-word thoughts won't trigger Claude (by design — typo guard).

## Out of scope for v1

- Per-command confirmation, command editing before run, streaming output,
  conversation history, configurable model, bash (non-zsh) support.

## Testing

- Unit-test the command-extraction function with `bats` or plain assertion
  script: blocks with bash/sh/shell, mixed prose, comment lines, no blocks.
- Manual smoke test of the handler: single word (no call), multi-word (calls a
  stubbed `ccline`), and a fake `claude` that returns a known answer with a
  fenced command to verify the run prompt.
- The `claude`-calling path is stubbed in tests (no live API in CI).
