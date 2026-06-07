#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"
command -v hermes >/dev/null 2>&1 && ok "hermes found: $(command -v hermes)" || { err "hermes missing"; exit 1; }
hermes profile list 2>/dev/null | grep -q 'shukhood' && ok "profile shukhood exists" || warn "profile shukhood missing"
PROFILE_HOME="$HOME/.hermes/profiles/shukhood"
[[ -d "$PROFILE_HOME/skills/shukhood-router" ]] && ok "shukhood-router installed in profile" || warn "shukhood-router missing from profile"
[[ -d "$PROFILE_HOME/skills/shukhood" ]] && ok "shukhood skill installed in profile" || warn "shukhood skill missing from profile"
find "$PROFILE_HOME/skills" -maxdepth 1 -name 'gstack*' 2>/dev/null | grep -q . && ok "GStack skills linked in profile" || warn "No GStack profile links detected"
info "Running hermes doctor..."
hermes doctor || true
