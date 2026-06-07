#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$SHUK_ROOT/core/banner.sh"
source "$SHUK_ROOT/core/logging.sh"
shuk_banner
mkdir -p "$HOME/.local/bin"
# Remove any previous symlink first; writing through a symlink would overwrite
# the repo's real bin/shuk and create a recursive launcher.
rm -f "$HOME/.local/bin/shuk"
cat > "$HOME/.local/bin/shuk" <<EOF
#!/usr/bin/env bash
export SHUK_ROOT="$SHUK_ROOT"
exec "$SHUK_ROOT/bin/shuk" "\$@"
EOF
chmod +x "$HOME/.local/bin/shuk"
ok "Installed shuk CLI -> $HOME/.local/bin/shuk"
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  warn "$HOME/.local/bin is not currently on PATH in this shell. Add it to your shell config if needed."
fi
info "Next: shuk doctor"
