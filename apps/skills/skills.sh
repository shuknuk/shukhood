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
  local skill_count
  if [[ -d "$SHUK_ROOT/skills" ]]; then
    skill_count=$(find "$SHUK_ROOT/skills" -maxdepth 1 -not -name '.*' -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    info "Skills: $skill_count top-level directories in skills/"
    if [[ "$skill_count" -eq 0 ]]; then
      warn "skills/ is empty — populate it before starting the server"
    fi
  else
    warn "skills/ directory not found"
  fi
}

sub="${1:-}"
case "$sub" in
  serve)    shift; _cmd_serve "$@" ;;
  check)    shift; _cmd_check "$@" ;;
  update)   shift; _cmd_update "$@" ;;
  status)   shift; _cmd_status "$@" ;;
  ""|--help|-h|help)
    cat <<'USAGE'
Usage: shuk skills <subcommand>

  serve           Start the skills MCP server (stdio)
  check           Report status for all source-tracked skills (offline)
  check --fetch   Same, also git fetch to check for new upstream commits
  update <name>   Update one source-tracked skill from upstream git
  update --all    Update all source-tracked skills from upstream git
  status          Show server config and skill counts

USAGE
    ;;
  *) err "Unknown subcommand: $sub"; exit 2 ;;
esac
