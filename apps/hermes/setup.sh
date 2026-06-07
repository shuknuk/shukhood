#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"
DRY_RUN=0
for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=1; done
run(){ if [[ "$DRY_RUN" == 1 ]]; then info "DRY RUN: $*"; else "$@"; fi; }
copy_file(){ src="$1"; dst="$2"; if [[ "$DRY_RUN" == 1 ]]; then info "DRY RUN: install $src -> $dst"; else mkdir -p "$(dirname "$dst")"; if [[ -e "$dst" && ! -L "$dst" ]]; then cp "$dst" "$dst.bak.$(date +%Y%m%d-%H%M%S)"; fi; cp "$src" "$dst"; ok "Installed $dst"; fi; }
link_dir(){ src="$1"; dst="$2"; if [[ "$DRY_RUN" == 1 ]]; then info "DRY RUN: symlink $dst -> $src"; else mkdir -p "$(dirname "$dst")"; rm -rf "$dst"; ln -s "$src" "$dst"; ok "Linked $dst -> $src"; fi; }
command -v hermes >/dev/null 2>&1 || { err "Hermes not found. Install official Hermes first."; exit 1; }
if ! hermes profile list 2>/dev/null | grep -q 'shukhood'; then
  run hermes profile create shukhood --clone default
else
  ok "Hermes profile shukhood already exists"
fi
PROFILE_HOME="$HOME/.hermes/profiles/shukhood"
if [[ -f "$HOME/.hermes/config.yaml" ]]; then
  copy_file "$HOME/.hermes/config.yaml" "$PROFILE_HOME/config.yaml"
else
  copy_file "$SHUK_ROOT/apps/hermes/profiles/shukhood/config.yaml.template" "$PROFILE_HOME/config.yaml"
fi
copy_file "$SHUK_ROOT/apps/hermes/profiles/shukhood/personality.md" "$PROFILE_HOME/personality.md"
copy_file "$SHUK_ROOT/apps/hermes/profiles/shukhood/personality.md" "$PROFILE_HOME/SOUL.md"
mkdir -p "$PROFILE_HOME/skills" 2>/dev/null || true
link_dir "$SHUK_ROOT/apps/hermes/skills/shukhood-router" "$PROFILE_HOME/skills/shukhood-router"
link_dir "$SHUK_ROOT/apps/hermes/skills/shukhood" "$PROFILE_HOME/skills/shukhood"
# Make current GStack skills visible in shukhood profile by symlinking local generated skills when present.
if [[ -d "$HOME/.hermes/skills" ]]; then
  while IFS= read -r -d '' d; do
    name="$(basename "$d")"
    case "$name" in
      gstack|gstack-*|qa|qa-only|review|ship|spec|investigate|health|design-review|design-html|land-and-deploy|dogfood|browse)
        [[ -e "$PROFILE_HOME/skills/$name" ]] || link_dir "$d" "$PROFILE_HOME/skills/$name"
        ;;
    esac
  done < <(find "$HOME/.hermes/skills" -maxdepth 1 -type d -name 'gstack*' -print0 2>/dev/null)
fi
ok "Hermes Shukhood setup complete"
info "Launch with: shuk hermes"
