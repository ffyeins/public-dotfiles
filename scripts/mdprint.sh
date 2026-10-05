#!/bin/zsh

SCRIPT_DIR="${0:a:h}"

case "$(uname -s)" in
    Linux*)     MDPRINT="$SCRIPT_DIR/mdprint-linux";;
    Darwin*)    MDPRINT="$SCRIPT_DIR/mdprint-macos-arm";;
    *)          echo "Unsupported OS"; exit 1;;
esac

"$MDPRINT" "$@"
