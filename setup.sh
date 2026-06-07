#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$SHUK_ROOT/core/banner.sh"
source "$SHUK_ROOT/core/logging.sh"
shuk_banner
mkdir -p "$HOME/.local/bin"
ln -sf "$SHUK_ROOT/bin/shuk" "$HOME/.local/bin/shuk"
ok "Linked shuk -> $HOME/.local/bin/shuk"
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  warn "$HOME/.local/bin is not currently on PATH in this shell. Add it to your shell config if needed."
fi
info "Next: shuk doctor"
