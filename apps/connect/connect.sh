#!/usr/bin/env bash
# shuk connect <client|--all|--list> — register the shukhood MCP server with AI clients.
#
# Supported clients: claude, codex, hermes
#
# Claude Code and Codex are registered automatically via their CLIs.
# Hermes prints a YAML block to paste into ~/.hermes/config.yaml — auto-write
# is intentionally avoided since that file is a live agent config.
set -euo pipefail

SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"

# ── Helpers: installed? ──────────────────────────────────────────────────────

_claude_installed()  { command -v claude  &>/dev/null; }
_codex_installed()   { command -v codex   &>/dev/null; }
_hermes_present()    { [[ -f "$HOME/.hermes/config.yaml" ]]; }

# ── Helpers: already registered? ────────────────────────────────────────────

_claude_registered() {
  _claude_installed || return 1
  # Exit 0 if 'shukhood' server exists in Claude Code config
  claude mcp get shukhood &>/dev/null 2>&1
}

_codex_registered() {
  _codex_installed || return 1
  codex mcp list 2>/dev/null | grep -q '^shukhood\b\|[[:space:]]shukhood[[:space:]]'
}

_hermes_registered() {
  _hermes_present || return 1
  grep -q 'shukhood' "$HOME/.hermes/config.yaml" 2>/dev/null
}

# ── Server health check ──────────────────────────────────────────────────────
# Sends a minimal JSON-RPC sequence (initialize → initialized → resources/list)
# and confirms the server returns a valid resources/list result.
#
# A sleep is appended to the input to hold stdin open long enough for the
# server to respond — FastMCP exits on EOF before finishing if stdin closes
# immediately after the last message.

_verify_server() {
  local result
  result=$(
    {
      printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shuk-connect-test","version":"0"}}}\n'
      printf '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n'
      printf '{"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}}\n'
      sleep 20
    } | perl -e 'alarm 25; exec @ARGV' -- \
        "$SHUK_ROOT/apps/skills/skills.sh" serve 2>/dev/null \
    | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        if obj.get('id') == 2:
            r = obj.get('result', {}).get('resources', [])
            print(len(r))
            break
    except Exception:
        pass
" 2>/dev/null
  ) || true

  if [[ -n "$result" && "$result" =~ ^[0-9]+$ && "$result" -gt 0 ]]; then
    ok "  server verified: $result resources in list_resources()"
    return 0
  else
    warn "  server health check inconclusive (try 'shuk skills serve' manually)"
    return 0  # non-fatal: registration itself succeeded
  fi
}

# ── Connect: Claude Code ─────────────────────────────────────────────────────

_connect_claude() {
  if ! _claude_installed; then
    warn "[claude] not installed — skipping"
    return 0
  fi

  if _claude_registered; then
    ok "[claude] already registered"
    return 0
  fi

  info "[claude] running: claude mcp add shukhood -- shuk skills serve"
  if claude mcp add shukhood -- shuk skills serve; then
    if _claude_registered; then
      ok "[claude] registration confirmed"
      _verify_server
    else
      err "[claude] 'claude mcp add' exited 0 but 'claude mcp get shukhood' still fails"
      return 1
    fi
  else
    err "[claude] 'claude mcp add' exited non-zero"
    return 1
  fi
}

# ── Connect: Codex ───────────────────────────────────────────────────────────

_connect_codex() {
  if ! _codex_installed; then
    warn "[codex] not installed — skipping"
    return 0
  fi

  if _codex_registered; then
    ok "[codex] already registered"
    return 0
  fi

  info "[codex] running: codex mcp add shukhood -- shuk skills serve"
  if codex mcp add shukhood -- shuk skills serve; then
    if _codex_registered; then
      ok "[codex] registration confirmed"
      _verify_server
    else
      err "[codex] 'codex mcp add' exited 0 but server not found in 'codex mcp list'"
      return 1
    fi
  else
    err "[codex] 'codex mcp add' exited non-zero"
    return 1
  fi
}

# ── Connect: Hermes ──────────────────────────────────────────────────────────

_hermes_yaml_block() {
  cat <<'YAML'
  shukhood:
    command: shuk
    args: [skills, serve]
    enabled: true
YAML
}

_connect_hermes() {
  if ! _hermes_present; then
    warn "[hermes] ~/.hermes/config.yaml not found — skipping"
    return 0
  fi

  if _hermes_registered; then
    ok "[hermes] already registered in ~/.hermes/config.yaml"
    return 0
  fi

  echo ""
  echo "  [hermes] Add the following block inside 'mcp_servers:' in ~/.hermes/config.yaml:"
  echo ""
  _hermes_yaml_block | sed 's/^/    /'
  echo ""
  info "  [hermes] After saving, restart Hermes to pick up the new server."
  info "  [hermes] Shukhood does not auto-write ~/.hermes/config.yaml (live agent config)."
  echo ""
}

# ── --list ───────────────────────────────────────────────────────────────────

_cmd_list() {
  echo ""
  echo "MCP client registration status:"
  echo ""

  # Claude Code
  if ! _claude_installed; then
    echo "  claude  not installed"
  elif _claude_registered; then
    ok "  claude  connected"
  else
    warn "  claude  installed, not connected  (run: shuk connect claude)"
  fi

  # Codex
  if ! _codex_installed; then
    echo "  codex   not installed"
  elif _codex_registered; then
    ok "  codex   connected"
  else
    warn "  codex   installed, not connected  (run: shuk connect codex)"
  fi

  # Hermes
  if ! _hermes_present; then
    echo "  hermes  not installed"
  elif _hermes_registered; then
    ok "  hermes  connected"
  else
    warn "  hermes  installed, not connected  (run: shuk connect hermes)"
  fi

  echo ""
}

# ── --all ────────────────────────────────────────────────────────────────────

_cmd_all() {
  echo ""
  info "Connecting all present MCP clients..."
  echo ""
  _connect_claude || true
  echo ""
  _connect_codex  || true
  echo ""
  _connect_hermes || true
}

# ── Usage ────────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
Usage:
  shuk connect claude          Register with Claude Code (claude mcp add)
  shuk connect codex           Register with Codex (codex mcp add)
  shuk connect hermes          Register with Hermes (prints YAML block to paste)
  shuk connect --all           Register with every present client
  shuk connect --list          Show registration status per client
USAGE
}

# ── Main ─────────────────────────────────────────────────────────────────────

target="${1:-}"

case "$target" in
  claude)       _connect_claude ;;
  codex)        _connect_codex  ;;
  hermes)       _connect_hermes ;;
  --all|-a)     _cmd_all        ;;
  --list|-l)    _cmd_list       ;;
  ""|--help|-h) usage           ;;
  *) err "Unknown client: $target"; echo ""; usage; exit 2 ;;
esac
