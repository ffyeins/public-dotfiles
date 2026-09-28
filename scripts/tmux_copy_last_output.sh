#!/bin/bash

# tmux-copy-last-output
#
# Copies the last command (prompt + output) from the current tmux pane
# to the system clipboard via pbcopy.
#
# Relies on the zsh prompt starting each block with "┌─" (set in .zshrc).
# The script scans the full pane scrollback for lines matching that pattern,
# then extracts everything between the second-to-last and last occurrence
# -- i.e. the most recently completed command and its output.
#
# Algorithm:
#   1. Capture full pane scrollback with tmux capture-pane
#   2. Find all line numbers starting with "┌─" (prompt delimiter)
#   3. Require at least 2 matches (previous prompt + current prompt)
#   4. Extract from second-to-last "┌─" up to (not including) the last "┌─"
#   5. Strip trailing blank lines, copy to clipboard
#
# Binding (in .tmux.conf):
#   bind-key y run-shell "~/dotfiles/scripts/tmux-copy-last-output"

# Capture full pane scrollback
content=$(tmux capture-pane -p -S -)

# Find all line numbers where a prompt block starts (┌─)
all_prompts=$(echo "$content" | grep -n '^┌─' | cut -d: -f1)
prompt_count=$(echo "$all_prompts" | wc -l | tr -d ' ')

if [[ "$prompt_count" -lt 2 ]]; then
    tmux display-message "Not enough command history (found $prompt_count prompts)"
    exit 1
fi

# Second-to-last ┌─ = start of the last completed command block
start=$(echo "$all_prompts" | tail -2 | head -1)

# Last ┌─ = start of current prompt (extract up to but not including this line)
end_exclusive=$(echo "$all_prompts" | tail -1)
end=$((end_exclusive - 1))

if [[ $end -lt $start ]]; then
    tmux display-message "No command output found"
    exit 1
fi

# Extract the block and strip trailing blank lines using awk (BSD sed compatible)
echo "$content" | sed -n "${start},${end}p" | awk '
    { lines[NR] = $0; last = NR }
    END {
        while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
        for (i = 1; i <= last; i++) print lines[i]
    }
' | pbcopy
tmux display-message "Copied last command output"
