#!/usr/bin/env bash
# shuk skills update [<name> | --all] — update one or all source-tracked skills.
#
# Pulls from the upstream git clone in ~/.hermes/sources/ (Hermes maintains
# these clones; we read from them). Then rsyncs the relevant subdirectory
# into skills/ and writes a fresh .shukhood-source.json.
#
# Decision matrix per skill:
#   local-mods=yes + git-ahead=yes  → CONFLICT: skip, report, do not overwrite
#   local-mods=yes + git-ahead=no   → nothing to do (no-op)
#   local-mods=no  + git-ahead=yes  → git pull, rsync, refresh provenance
#   local-mods=no  + git-ahead=no   → already current (no-op)
#
# Does NOT touch ~/.hermes/ in any way besides reading from ~/.hermes/sources/.
set -euo pipefail

SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"

DEST="$SHUK_ROOT/skills"
SOURCES_JSON="$SHUK_ROOT/apps/skills/skill-sources.json"

# ---------------------------------------------------------------------------
# Content hash (identical to check.sh)
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
    warn "  [$name] no .shukhood-source.json — provenance missing"
    return 3
  fi

  local stype source_name remote repo_path branch recorded_hash install_mode dest_category
  stype="$(jq -r '.source_type'       "$prov_file" 2>/dev/null || echo "")"
  source_name="$(jq -r '.source_name' "$prov_file" 2>/dev/null || echo "")"
  remote="$(jq -r '.remote'           "$prov_file" 2>/dev/null || echo "")"
  repo_path="$(jq -r '.source_repo_path' "$prov_file" 2>/dev/null || echo "")"
  branch="$(jq -r '.source_branch'    "$prov_file" 2>/dev/null || echo "")"
  recorded_hash="$(jq -r '.content_hash'  "$prov_file" 2>/dev/null || echo "")"

  if [[ "$stype" != "source-tracked" ]]; then
    info "  [$name] local skill — skipped (no upstream)"
    return 3
  fi

  if [[ -z "$repo_path" || "$repo_path" == "null" || ! -d "$repo_path/.git" ]]; then
    warn "  [$name] source git clone not found at: $repo_path"
    warn "         (Hermes manages these clones; ensure Hermes has installed this skill)"
    return 3
  fi

  local vendored_dir="$DEST/$name"

  # ── Check for local modifications ────────────────────────────────────────
  local local_modified=0
  if [[ -n "$recorded_hash" && "$recorded_hash" != "null" ]]; then
    local current_hash
    current_hash="$(_content_hash "$vendored_dir" || echo "")"
    [[ "$current_hash" != "$recorded_hash" ]] && local_modified=1
  fi

  # ── Pull from upstream and check if anything changed ─────────────────────
  git -C "$repo_path" fetch --quiet origin 2>/dev/null || true
  local origin_commit recorded_commit git_behind=0
  recorded_commit="$(jq -r '.source_commit' "$prov_file" 2>/dev/null || echo "")"
  origin_commit="$(git -C "$repo_path" rev-parse "origin/${branch}" 2>/dev/null || echo "")"

  if [[ -n "$origin_commit" && -n "$recorded_commit" && "$recorded_commit" != "null" ]]; then
    [[ "$origin_commit" != "$recorded_commit" ]] && git_behind=1
  fi

  # ── Decision ─────────────────────────────────────────────────────────────
  if [[ "$local_modified" -eq 1 && "$git_behind" -eq 1 ]]; then
    err "  [$name] CONFLICT — local edits detected AND upstream has new commits"
    echo "          Resolve manually, then re-run 'shuk skills update $name'"
    return 2
  fi

  if [[ "$local_modified" -eq 1 && "$git_behind" -eq 0 ]]; then
    info "  [$name] local edits present but upstream is not ahead — nothing to do"
    return 1
  fi

  if [[ "$git_behind" -eq 0 ]]; then
    ok "  [$name] already current"
    return 1
  fi

  # ── Safe to update: git pull, then rsync from the relevant subdir ─────────
  git -C "$repo_path" pull --ff-only --quiet origin "$branch" 2>/dev/null || {
    warn "  [$name] git pull failed — skipping"
    return 3
  }

  # Find which subdir within the repo maps to this skill.
  # The source entry in skill-sources.json has dest_category (e.g. "ios" or "medical-research").
  # The repo_path is the full git clone root. We need to find what within it maps to this skill.
  # For install_mode=flatten-skill-dirs, individual skill dirs within the clone become skills.
  # For single-dir installs, the clone root IS the skill.
  # We use the recorded source_name to look up install_mode from skill-sources.json.
  local src_dir
  if [[ -f "$SOURCES_JSON" ]] && command -v jq >/dev/null 2>&1; then
    local install_mode
    install_mode="$(jq -r --arg sn "$source_name" \
      '.sources[] | select(.name == $sn) | .install_mode // "single-dir"' \
      "$SOURCES_JSON" 2>/dev/null)"
    if [[ "$install_mode" == "flatten-skill-dirs" ]]; then
      # The skill dir name inside the repo clone corresponds to the final component of skills/<name>
      # E.g. skills/medical-research/<subskill> — src_dir = $repo_path/<subskill>
      local sub="${name##*/}"
      src_dir="$repo_path/$sub"
    else
      src_dir="$repo_path"
    fi
  else
    src_dir="$repo_path"
  fi

  if [[ ! -d "$src_dir" ]]; then
    warn "  [$name] source dir not found after pull: $src_dir"
    return 3
  fi

  rsync -a --delete \
    --exclude='.DS_Store' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.git/' \
    --exclude='.shukhood-source.json' \
    "$src_dir/" "$vendored_dir/" 2>/dev/null

  local new_hash new_commit last_synced
  new_hash="$(_content_hash "$vendored_dir" || echo "")"
  new_commit="$(git -C "$repo_path" rev-parse HEAD 2>/dev/null || echo "")"
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
  "synced_from": "canonical-repo",
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
    _update_one "$name" || true
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
