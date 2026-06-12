Output "/Users/jianshuo/code/ccline/docs/demo.gif"

Set Shell fish
Set FontSize 18
Set Width 1100
Set Height 560
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 60ms
Set PlaybackSpeed 1.0

# --- hidden setup: stub claude + real ccline on PATH, load the fish handler ---
Hide
Type "set -gx PATH /tmp/ccline-demo-bin $HOME/.local/bin $PATH"
Enter
Type "source $HOME/.config/fish/functions/fish_command_not_found.fish"
Enter
Type "cd /tmp/ccline-demo; and clear"
Enter
Show

Sleep 700ms
# Just type a thought at the prompt — no command, no prefix.
Type "how do I list the most recently changed files here"
Sleep 900ms
Enter

# claude answers (rendered), then the command menu appears.
Sleep 2s
# Arrow down to the human-readable variant, run it.
Down
Sleep 1100ms
Enter
Sleep 2800ms
