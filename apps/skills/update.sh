#!/usr/bin/env bash
# shuk skills update [<name> | --all] — re-vendor one or all source-tracked skills.
#
# Decision matrix per skill:
#   local-mods=yes + hermes-updated=yes  → CONFLICT: skip, report, do not overwrite
#   local-mods=yes + hermes-updated=no   → nothing to do (no-op)
#   local-mods=no  + hermes-updated=yes  → update vendored copy, refresh provenance
#   local-mods=no  + hermes-updated=no   → already current (no-op)
#
# Does NOT touch ~/.hermes/ or git repos — those are Hermes' responsibility.
set -euo pipefail

SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"

DEST="$SHUK_ROOT/skills"

# ---------------------------------------------------------------------------
# Content hash (identical to sync.sh and check.sh)
# ---------------------------------------------------------------------------
_content_hash() {
  local dir="$1"
  (
    cd "$dir" 2>/dev/null || { echo ""; return 1; }
    find . -type f \
      ! -name '.shukhood-source.json' \
      ! -name '.DS_Store' \
      2>/dev/null \
    | sort \
    | while IFS= read -r f; do
        shasum -a 256 "$f" 2>/dev/null
      done
  ) | shasum -a 256 2>/dev/null | awk '{print $1}'
}

# ---------------------------------------------------------------------------
# Update a single skill dir. Returns 0=updated, 1=current/noop, 2=conflict, 3=skip
# ---------------------------------------------------------------------------
_update_one() {
  local name="$1"
  local prov_file="$DEST/$name/.shukhood-source.json"

  if [[ ! -f "$prov_file" ]]; then
    warn "  [$name] no .shukhood-source.json — run 'shuk skills sync' first"
    return 3
  fi

  # Read ALL fields from provenance BEFORE rsync (rsync --delete will remove the file)
  local stype source_name remote repo_path branch recorded_hash synced_from
  stype="$(jq -r '.source_type'       "$prov_file" 2>/dev/null || echo "")"
  source_name="$(jq -r '.source_name' "$prov_file" 2>/dev/null || echo "")"
  remote="$(jq -r '.remote'           "$prov_file" 2>/dev/null || echo "")"
  repo_path="$(jq -r '.source_repo_path' "$prov_file" 2>/dev/null || echo "")"
  branch="$(jq -r '.source_branch'    "$prov_file" 2>/dev/null || echo "")"
  recorded_hash="$(jq -r '.content_hash'  "$prov_file" 2>/dev/null || echo "")"
  synced_from="$(jq -r '.synced_from' "$prov_file" 2>/dev/null || echo "")"

  if [[ "$stype" != "source-tracked" ]]; then
    info "  [$name] local skill — skipped (no upstream)"
    return 3
  fi

  local vendored_dir="$DEST/$name"
  local hermes_dir="$synced_from"

  if [[ ! -d "$hermes_dir" ]]; then
    warn "  [$name] Hermes install dir not found: $hermes_dir"
    return 3
  fi

  # ── Check for local modifications ────────────────────────────────────────
  local local_modified=0
  if [[ -n "$recorded_hash" && "$recorded_hash" != "null" ]]; then
    local current_hash
    current_hash="$(_content_hash "$vendored_dir" || echo "")"
    [[ "$current_hash" != "$recorded_hash" ]] && local_modified=1
  fi

  # ── Check if Hermes has an updated install ───────────────────────────────
  local hermes_updated=0
  local hermes_hash
  hermes_hash="$(_content_hash "$hermes_dir" || echo "")"
  if [[ -n "$recorded_hash" && "$recorded_hash" != "null" && "$hermes_hash" != "$recorded_hash" ]]; then
    hermes_updated=1
  fi

  # ── Decision ─────────────────────────────────────────────────────────────
  if [[ "$local_modified" -eq 1 && "$hermes_updated" -eq 1 ]]; then
    err "  [$name] CONFLICT — local edits detected AND Hermes has an update"
    echo "          skills/$name/ was modified after last sync"
    echo "          ~/.hermes/skills/$name/ has also changed"
    echo "          Resolve manually, then re-run 'shuk skills sync' to force re-vendor"
    return 2
  fi

  if [[ "$local_modified" -eq 1 && "$hermes_updated" -eq 0 ]]; then
    info "  [$name] local edits present but Hermes has no update — nothing to do"
    return 1
  fi

  if [[ "$hermes_updated" -eq 0 ]]; then
    ok "  [$name] already current"
    return 1
  fi

  # ── Safe to update ───────────────────────────────────────────────────────
  # rsync --delete removes .shukhood-source.json (it lives only in vendored, not in Hermes)
  # We write a fresh one immediately after.
  rsync -a --delete \
    --exclude='.DS_Store' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.git/' \
    "$hermes_dir" "$vendored_dir/" 2>/dev/null

  local new_hash new_commit last_synced
  new_hash="$(_content_hash "$vendored_dir" || echo "")"
  new_commit=""
  if [[ -n "$repo_path" && -d "$repo_path/.git" ]]; then
    new_commit="$(git -C "$repo_path" rev-parse HEAD 2>/dev/null || echo "")"
  fi
  last_synced="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  cat > "$prov_file" <<EOF
{
  "skill": "$name",
  "source_type": "source-tracked",
  "source_name": "$source_name",
  "remote": "$remote",
  "source_repo_path": "$repo_path",
  "source_branch": "$branch",
  "source_commit": "$new_commit",
  "synced_from": "$synced_from",
  "last_synced": "$last_synced",
  "content_hash": "$new_hash"
}
EOF

  ok "  [$name] updated → ${new_commit:0:8}"
  return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
target="${1:-}"

if [[ -z "$target" ]]; then
  echo "Usage: shuk skills update <name>"
  echo "       shuk skills update --all"
  exit 1
fi

if [[ "$target" == "--all" ]]; then
  n_updated=0; n_current=0; n_conflict=0; n_skip=0
  for prov_file in "$DEST"/*/.shukhood-source.json; do
    [[ -f "$prov_file" ]] || continue
    stype="$(jq -r '.source_type' "$prov_file" 2>/dev/null || echo "")"
    [[ "$stype" != "source-tracked" ]] && continue
    name="$(jq -r '.skill' "$prov_file" 2>/dev/null || echo "")"
    [[ -z "$name" ]] && continue
    _update_one "$name" || true  # capture rc via $?
    rc=$?
    case $rc in
      0) n_updated=$((n_updated+1)) ;;
      1) n_current=$((n_current+1)) ;;
      2) n_conflict=$((n_conflict+1)) ;;
      3) n_skip=$((n_skip+1)) ;;
    esac
  done
  echo ""
  echo "Update summary:"
  [[ "$n_updated"  -gt 0 ]] && ok   "$n_updated updated"
  [[ "$n_current"  -gt 0 ]] && ok   "$n_current already current"
  [[ "$n_conflict" -gt 0 ]] && err  "$n_conflict conflicts (skipped — manual resolution needed)"
  [[ "$n_skip"     -gt 0 ]] && info "$n_skip skipped (local or missing provenance)"
else
  if [[ ! -d "$DEST/$target" ]]; then
    err "Skill '$target' not found in $DEST"
    exit 1
  fi
  _update_one "$target" || true
fi
