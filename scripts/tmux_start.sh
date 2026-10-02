#!/bin/bash
# Create a tmux session with its standard layout (unless it already exists),
# then attach to it. Usage: tmux_start.sh main|secondary
#
# Run from an interactive terminal, not launchd: a server started here
# inherits this shell's environment and passes it to every pane.
set -uo pipefail

session="${1:?usage: tmux_start.sh main|secondary}"

# Window 1 ("repo") pane directories (placeholders: replace with real repo paths)
repo_dir_1=~/path/to/repo-1/
repo_dir_2=~/path/to/repo-2/
repo_dir_3=~/path/to/repo-3/

build_main() {
    # Size the detached session to this terminal so splits keep their proportions on attach
    local cols lines
    cols=$(tput cols 2>/dev/null) || cols=80
    lines=$(tput lines 2>/dev/null) || lines=24
    tmux new-session -d -s main -n default -c ~ -x "$cols" -y "$lines"

    # Window 1: repo — left | right-top / right-bottom
    tmux new-window   -d -t main:1 -n repo -c ~
    tmux split-window -d -h -t main:1.0 -c ~
    tmux split-window -d -v -t main:1.1 -c ~
    tmux send-keys -t main:1.0 "cd $repo_dir_1" C-m
    tmux send-keys -t main:1.1 "cd $repo_dir_2" C-m
    tmux send-keys -t main:1.2 "cd $repo_dir_3" C-m

    # Window 2: remote SSH connections (no routine yet)
    tmux new-window -d -t main:2 -n ssh -c ~
}

if ! tmux has-session -t "=$session" 2>/dev/null; then
    case "$session" in
        main) build_main ;;
        *)    tmux new-session -d -s "$session" -c ~ ;;
    esac
fi

# Already inside tmux (manual re-run): switch instead of nesting
if [ -n "${TMUX:-}" ]; then
    exec tmux switch-client -t "=$session"
fi
exec tmux attach-session -t "=$session"
