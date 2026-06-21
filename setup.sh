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

# ── Windows (Git Bash / Cygwin): also create a .cmd shim ────────────────────
# .cmd files are in PATHEXT by default, so `shuk` (no extension) works from
# both PowerShell and CMD without any PATHEXT changes.
if [[ "${OSTYPE:-}" == "msys"* || "${OSTYPE:-}" == "cygwin"* || -n "${COMSPEC:-}" ]]; then
  _bash_win="$(cygpath -w "$(which bash)" 2>/dev/null || true)"
  _shuk_win="$(cygpath -w "$SHUK_ROOT/bin/shuk" 2>/dev/null || true)"
  _bin_win="$(cygpath -w "$HOME/.local/bin" 2>/dev/null || true)"

  if [[ -n "$_bash_win" && -n "$_shuk_win" ]]; then
    printf '@echo off\r\n"%s" "%s" %%*\r\n' "$_bash_win" "$_shuk_win" \
      > "$HOME/.local/bin/shuk.cmd"
    ok "Created .cmd shim  -> $HOME/.local/bin/shuk.cmd"
  fi

  # Persist ~/.local/bin in the Windows User PATH so it survives terminal restarts.
  if [[ -n "$_bin_win" ]] && command -v powershell.exe &>/dev/null; then
    _ps_script="$(mktemp --suffix=.ps1)"
    cat > "$_ps_script" <<PSEOF
\$p = [Environment]::GetEnvironmentVariable('PATH', 'User')
if (\$p -notlike '*${_bin_win}*') {
  [Environment]::SetEnvironmentVariable('PATH', "\$p;${_bin_win}", 'User')
  exit 0
} else { exit 1 }
PSEOF
    if powershell.exe -NoProfile -ExecutionPolicy Bypass \
         -File "$(cygpath -w "$_ps_script")" 2>/dev/null; then
      ok "Added $_bin_win to Windows User PATH (restart terminal to apply)"
    else
      ok "$_bin_win already in Windows User PATH"
    fi
    rm -f "$_ps_script"
  fi
fi

# ── Unix PATH reminder ────────────────────────────────────────────────────────
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  warn "$HOME/.local/bin is not on PATH in this shell. Add it to your shell config if needed."
fi
info "Next: shuk doctor"
