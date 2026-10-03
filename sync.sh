#!/bin/sh
# Copy the paths listed in file-list.txt from ~/dotfiles into this repo.
# Extra arguments go to rsync, e.g. `./sync.sh -nv` for a dry run.
set -eu

repo=$(cd "$(dirname "$0")" && pwd)

printf '\033[1mSyncing with dotfiles...\033[0m\n'
rsync -arL --files-from="$repo/file-list.txt" "$@" "$HOME/dotfiles/" "$repo/"
printf '\033[1mOK\033[0m\n\n'

printf '\033[1mCommitting changes...\033[0m'
git add .
git cm "update"
printf '\033[1mOK\033[0m\n\n'

printf '\033[1mGit status:\033[0m\n'
git st
