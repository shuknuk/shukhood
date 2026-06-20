#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SHUK_ROOT/core/banner.sh"
source "$SHUK_ROOT/core/logging.sh"
shuk_banner
check_cmd(){ if command -v "$1" >/dev/null 2>&1; then ok "$1 found ($(command -v "$1"))"; else warn "$1 missing"; fi; }
info "Checking core tools..."
for c in git gh curl jq node npm npx python3 uv; do check_cmd "$c"; done
info "Checking AI clients..."
for c in hermes codex claude agy opencode; do check_cmd "$c"; done
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh authenticated"; else warn "gh installed but not authenticated"; fi
fi
info "Checking skills directory..."
skill_count=$(find "$SHUK_ROOT/skills" -maxdepth 1 -not -name '.*' -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
if [[ "$skill_count" -gt 0 ]]; then
  ok "skills/ populated: $skill_count directories"
else
  warn "skills/ is empty — no skills available to serve"
fi
info "Checking MCP client connections..."
"$SHUK_ROOT/apps/connect/connect.sh" --list 2>/dev/null || true
info "Checking secrets template..."
[[ -f "$SHUK_ROOT/secrets/.env.example" ]] && ok "secrets/.env.example present" || warn "secrets/.env.example missing"
