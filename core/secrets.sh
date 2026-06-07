#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"
case "${1:-check}" in
  check)
    info "Checking local secret hints (values are never printed)."
    envfile="$HOME/.hermes/.env"
    [[ -f "$envfile" ]] && ok "Hermes env file exists: $envfile" || warn "Hermes env file missing: $envfile"
    while IFS= read -r key; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      name="${key%%=*}"
      if [[ -n "${!name:-}" ]] || { [[ -f "$envfile" ]] && grep -q "^$name=" "$envfile"; }; then ok "$name present"; else skip "$name not set"; fi
    done < "$SHUK_ROOT/secrets/.env.example"
    ;;
  init)
    target="$HOME/.hermes/.env"
    mkdir -p "$HOME/.hermes"
    if [[ -e "$target" ]]; then warn "$target already exists; not overwriting"; else cp "$SHUK_ROOT/secrets/.env.example" "$target"; ok "Created $target from template"; fi
    ;;
  *) err "Usage: shuk secrets [check|init]"; exit 2 ;;
esac
