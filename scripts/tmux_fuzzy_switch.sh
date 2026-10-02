#!/bin/bash
# Fuzzy-find a tmux session or window and switch to it, previewing its active pane.
# Runs in a popup from prefix + w (.tmux.conf). Type part of a name ("data" for
# "database") and Enter jumps to the top match; Esc closes without switching.
set -uo pipefail

# Preview: the pane's screen without the blank rows below its last output, so
# fzf's follow can keep the bottom (the prompt) in view like the real pane
if [ "${1:-}" = --preview ]; then
    tmux capture-pane -ep -t "$2" |
        awk 'NF { while (blank > 0) { print ""; blank-- } print; next } { blank++ }'
    exit
fi

# One line per session followed by its windows, as "target<TAB>label". The "="
# makes the target match the session name exactly. Windows are labelled like the
# status bar: the custom name if renamed, otherwise the current directory.
list() {
    tmux list-windows -a -F "#{session_name}	#{window_index}	#{?automatic-rename,#{b:pane_current_path},#{window_name}}" |
        awk -F '\t' '
            $1 != session { session = $1; print "=" session ":\t" session }
            { print "=" $1 ":" $2 "\t    " $1 ":" $2 "  " $3 }'
}

target=$(list | fzf --reverse --delimiter '\t' --with-nth 2 --accept-nth 1 \
    --preview "'$0' --preview {1}" --preview-window 'right,80%,follow') || exit 0
tmux switch-client -t "$target"
