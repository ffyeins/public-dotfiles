#!/bin/sh
# Copy the paths listed in file-list.txt from ~/dotfiles into this repo.
# Extra arguments go to rsync, e.g. `./sync.sh -nv` for a dry run.
set -eu

repo=$(cd "$(dirname "$0")" && pwd)

rsync -arL --files-from="$repo/file-list.txt" "$@" "$HOME/dotfiles/" "$repo/"

git add .

git cm "update"

git st
