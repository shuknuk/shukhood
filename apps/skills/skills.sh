#!/usr/bin/env bash
# shuk skills — manage and serve the Shukhood skills MCP server.
set -euo pipefail

SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"

SKILLS_APP="$SHUK_ROOT/apps/skills"
VENV="$SKILLS_APP/.venv"
SERVER="$SKILLS_APP/server.py"

_ensure_venv() {
  if [[ ! -d "$VENV" ]]; then
    info "Creating Python venv for skills server..."
    uv venv --python 3.11 "$VENV"
  fi
  if ! "$VENV/bin/python" -c "import fastmcp" 2>/dev/null; then
    info "Installing dependencies..."
    uv pip install --python "$VENV/bin/python" -r <(uv pip compile "$SKILLS_APP/pyproject.toml" 2>/dev/null || echo "fastmcp>=3.0")
    # Simpler direct install:
    "$VENV/bin/pip" install "fastmcp>=3.0" --quiet
  fi
}

_cmd_serve() {
  _ensure_venv
  local skills_dir="${SHUKHOOD_SKILLS_DIR:-}"
  if [[ -z "$skills_dir" && -d "$SHUK_ROOT/skills" ]]; then
    local count
    count=$(find "$SHUK_ROOT/skills" -maxdepth 1 -not -name '.*' -mindepth 1 | wc -l | tr -d ' ')
    if [[ "$count" -gt 0 ]]; then
      export SHUKHOOD_SKILLS_DIR="$SHUK_ROOT/skills"
    fi
  fi
  exec "$VENV/bin/python" "$SERVER"
}

_cmd_sync() {
  exec "$SKILLS_APP/sync.sh" "$@"
}

_cmd_check() {
  exec "$SKILLS_APP/check.sh" "$@"
}

_cmd_update() {
  exec "$SKILLS_APP/update.sh" "$@"
}

_cmd_status() {
  _ensure_venv
  info "Skills server: $SERVER"
  info "Venv: $VENV"
  local hermes_count vendored_count
  hermes_count=$(find "$HOME/.hermes/skills" -maxdepth 1 -not -name '.*' -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  info "Hermes skills available: $hermes_count"
  if [[ -d "$SHUK_ROOT/skills" ]]; then
    vendored_count=$(find "$SHUK_ROOT/skills" -maxdepth 1 -not -name '.*' -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    info "Vendored skills (skills/): $vendored_count"
    if [[ "$vendored_count" -eq 0 ]]; then
      warn "No vendored skills yet — run 'shuk skills sync' to populate skills/"
    fi
  else
    warn "skills/ dir not found — server will read from ~/.hermes/skills/ directly"
  fi
}

sub="${1:-}"
case "$sub" in
  serve)    shift; _cmd_serve "$@" ;;
  sync)     shift; _cmd_sync "$@" ;;
  check)    shift; _cmd_check "$@" ;;
  update)   shift; _cmd_update "$@" ;;
  status)   shift; _cmd_status "$@" ;;
  ""|--help|-h|help)
    cat <<'USAGE'
Usage: shuk skills <subcommand>

  serve              Start the skills MCP server (stdio)
  sync               Vendor ~/.hermes/skills/ into skills/ with provenance
  check [--no-fetch] Report sync status for all source-tracked skills
  update <name>      Re-vendor one source-tracked skill (conflict-safe)
  update --all       Re-vendor all source-tracked skills
  status             Show server config and skill counts

USAGE
    ;;
  *) err "Unknown subcommand: $sub"; exit 2 ;;
esac
