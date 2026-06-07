#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SHUK_ROOT/core/banner.sh"
source "$SHUK_ROOT/core/logging.sh"
shuk_banner
check_cmd(){ if command -v "$1" >/dev/null 2>&1; then ok "$1 found ($(command -v "$1"))"; else warn "$1 missing"; fi; }
info "Checking core tools..."
for c in git gh curl jq node npm npx python3 uv; do check_cmd "$c"; done
info "Checking AI tools..."
for c in hermes codex claude agy opencode; do check_cmd "$c"; done
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh authenticated"; else warn "gh installed but not authenticated"; fi
fi
if command -v hermes >/dev/null 2>&1; then
  info "Checking Hermes profile and skills..."
  hermes profile list 2>/dev/null | grep -q 'shukhood' && ok "Hermes profile shukhood exists" || warn "Hermes profile shukhood not created yet (run: shuk hermes setup)"
  if [[ -d "$HOME/.hermes/skills" ]] && find "$HOME/.hermes/skills" -maxdepth 1 -type d -name 'gstack*' | grep -q .; then
    ok "GStack skills present in ~/.hermes/skills"
  else
    warn "GStack skills not detected in ~/.hermes/skills"
  fi
  if [[ -d "$HOME/.hermes/profiles/shukhood/skills/shukhood-router" ]] || [[ -d "$HOME/.hermes/skills/shukhood-router" ]]; then
    ok "shukhood-router skill present"
  else
    warn "shukhood-router not installed yet (run: shuk hermes setup)"
  fi
fi
info "Checking secret template..."
[[ -f "$SHUK_ROOT/secrets/.env.example" ]] && ok "secrets/.env.example present" || warn "secrets/.env.example missing"
