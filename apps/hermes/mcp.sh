#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"
case "${1:-list}" in
  list) cat "$SHUK_ROOT/shared/mcp/registry.yaml" ;;
  doctor) info "MCP registry present: $SHUK_ROOT/shared/mcp/registry.yaml"; [[ -f "$SHUK_ROOT/shared/mcp/registry.yaml" ]] && ok "registry found" || warn "registry missing" ;;
  *) err "Usage: shuk mcp [list|doctor]"; exit 2 ;;
esac
