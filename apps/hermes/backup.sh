#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"
DRY_RUN=0
for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=1; done
copy_safe(){ src="$1"; dst="$2"; if [[ ! -e "$src" ]]; then skip "Missing $src"; return; fi; if [[ "$DRY_RUN" == 1 ]]; then info "DRY RUN: copy $src -> $dst"; else mkdir -p "$(dirname "$dst")"; cp -R "$src" "$dst"; ok "Copied $src -> $dst"; fi; }
PROFILE_HOME="$HOME/.hermes/profiles/shukhood"
copy_safe "$PROFILE_HOME/config.yaml" "$SHUK_ROOT/apps/hermes/profiles/shukhood/config.yaml.backup"
copy_safe "$PROFILE_HOME/personality.md" "$SHUK_ROOT/apps/hermes/profiles/shukhood/personality.md.backup"
warn "Skipped secrets, auth, sessions, logs, memories, browser cookies, and caches."
info "Review git status before committing."
