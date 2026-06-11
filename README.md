# ccline (fish edition)

[![GitHub stars](https://img.shields.io/github/stars/light4/ccline.fish?style=flat-square)](https://github.com/light4/ccline.fish/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

Type a thought directly at your fish prompt — no command, no prefix — and get
an answer. If the answer contains shell commands, confirm once and run them.

![ccline demo](docs/demo.gif)

```
$ how do I find files bigger than 100MB here

    find . -maxdepth 1 -type f -size +100M       (rendered, colorized)

This lists files in the current directory only.

Commands found — ↑/↓ to choose, Enter to run, q to cancel:
 ❯ find . -maxdepth 1 -type f -size +100M
   find . -type f -size +100M
   ➤ Run all of them
   ✗ Cancel
$ find . -maxdepth 1 -type f -size +100M
./big.iso
```

The answer is rendered as Markdown (headings, bold, inline code, bullets, and
colorized code blocks) when printed to a terminal.

## Why ccline?

You're in the terminal and need to remember a command. Your options:
- Leave the terminal to Google it, copy, paste back
- Open a new Claude window, ask, copy, paste back
- Open a new terminal tab, run `claude -p "..."`, copy

With ccline: just type the question where you already are. The answer appears
inline, and if there's a runnable command, one keypress executes it in your live
fish session — `cd`, `set`, abbreviations, history and all.

## How it works

It hijacks fish's `fish_command_not_found`. When you type something that
isn't a real command, fish hands the whole line to ccline:

- **One word** (`gti`) → treated as a normal typo: `fish: Unknown command: gti`.
- **Two or more words** → treated as a thought, sent to your LLM CLI. The answer
  is rendered as Markdown. Any runnable commands are shown in an arrow-key menu —
  **↑/↓** to move, **Enter** to run the highlighted command (or "Run all of
  them"), **q** to cancel. When stdout isn't a terminal (piped/redirected), it
  falls back to a typed prompt (`1-N`, `a`=all, Enter=none).

It uses the [`claude`](https://claude.com/claude-code) CLI if installed
(preferred), otherwise the [`codex`](https://github.com/openai/codex) CLI —
auto-detected. Force one with `CCLINE_BACKEND=claude` or `CCLINE_BACKEND=codex`.

Markdown rendering uses [`glow`](https://github.com/charmbracelet/glow) if it's
installed; otherwise a built-in `perl` renderer (no extra dependency).

## Requirements

- [fish](https://fishshell.com) 3.1 or newer
- One of these on your `PATH`, authenticated:
  - [`claude`](https://claude.com/claude-code) (preferred), or
  - [`codex`](https://github.com/openai/codex) (fallback)

## Install

**Fisher** (recommended):

```fish
fisher install light4/ccline.fish
```

**One-line install script** (no Fisher required):

```sh
curl -fsSL https://raw.githubusercontent.com/light4/ccline.fish/main/install.sh | bash
```

**From a clone**:

```sh
git clone https://github.com/light4/ccline.fish.git
cd ccline.fish && ./install.sh
```

All three put the same two files in place:
- `~/.config/fish/functions/ccline.fish` — the `ccline` function (autoloaded)
- `~/.config/fish/conf.d/ccline.fish` — `fish_command_not_found` handler
  (auto-sourced by fish on startup)

No edits to `config.fish` are needed. Open a new fish session, or
`source ~/.config/fish/conf.d/ccline.fish` to activate in this one.

## Configuration

- `CCLINE_BACKEND` — force the LLM CLI: `claude` or `codex`. Default is
  auto-detect (claude preferred, codex fallback).
- `CCLINE_MODEL` — override the model. The claude backend defaults to
  `claude-sonnet-4-6` (fastest end-to-end for these short prompts); set this to
  use another, e.g. `set -gx CCLINE_MODEL claude-opus-4-8`. Passed as `--model`
  to whichever backend is used.

## Running commands

When you trigger ccline by typing at the prompt (the normal path), the chosen
command runs in **your live fish session** — so `cd`, `set`, abbreviations,
functions, and history all work and persist, exactly as if you'd typed it.
(ccline writes the selection to a temp file and the fish handler `eval`s it.)

Running `ccline …` directly as a command instead runs the selection in a
subprocess, so shell-state changes like `cd` won't persist there.

## Limitations

- Single-word thoughts won't reach Claude — by design, so typos stay fast.

## Uninstall

```fish
fisher remove light4/ccline.fish
```

Or without Fisher:

```sh
rm -f ~/.config/fish/functions/ccline.fish
rm -f ~/.config/fish/conf.d/ccline.fish
```

## Tests

```sh
fish tests/test_ccline.fish
```
