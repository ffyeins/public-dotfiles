# Dedupe PATH, keeping first occurrence. Must come before any PATH edit:
# nested login shells re-run /etc/zprofile (path_helper) and .zshrc, which
# would otherwise append duplicate entries each time.
typeset -U path PATH

# uv
export PATH="$HOME/.local/bin:$PATH"
