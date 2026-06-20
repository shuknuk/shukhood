#!/usr/bin/env bash
# shuk skills check — read-only status report for all source-tracked skills.
#
# For each source-tracked skill, checks two things:
#   1. Local mods:   has skills/<name>/ been edited since last snapshot?
#   2. Git upstream: does the upstream repo have commits beyond our snapshot?
#      Checks against sources/<source_name>/ if already cloned (no network).
#      Pass --fetch to run git fetch first (requires network).
#
# No files are modified. Clones are never created here — run shuk skills update to clone.
set -euo pipefail

SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"

DEST="$SHUK_ROOT/skills"
SOURCES_DIR="$SHUK_ROOT/sources"
DO_FETCH=0

for arg in "$@"; do
  [[ "$arg" == "--fetch" ]] && DO_FETCH=1
done

# ---------------------------------------------------------------------------
# Content hash (same as update.sh)
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
# Scan skills/
# ---------------------------------------------------------------------------
found_any=0
n_current=0
n_git_behind=0
n_local_mod=0
n_conflict=0
n_no_clone=0

for prov_file in "$DEST"/*/.shukhood-source.json; do
  [[ -f "$prov_file" ]] || continue

  name="$(jq -r '.skill'             "$prov_file" 2>/dev/null)"
  stype="$(jq -r '.source_type'      "$prov_file" 2>/dev/null)"
  [[ "$stype" != "source-tracked" ]] && continue

  found_any=1
  source_name="$(jq -r '.source_name'     "$prov_file" 2>/dev/null)"
  branch="$(jq -r '.source_branch'        "$prov_file" 2>/dev/null)"
  recorded_commit="$(jq -r '.source_commit' "$prov_file" 2>/dev/null)"
  recorded_hash="$(jq -r '.content_hash'  "$prov_file" 2>/dev/null)"
  last_synced="$(jq -r '.last_synced'     "$prov_file" 2>/dev/null)"

  vendored_dir="$DEST/$name"
  clone_dir="$SOURCES_DIR/$source_name"

  # ── 1. Local modification check ──────────────────────────────────────────
  local_modified=0
  local_mod_note=""
  if [[ -z "$recorded_hash" || "$recorded_hash" == "null" ]]; then
    local_mod_note="(no hash recorded — run 'shuk skills update $name' to baseline)"
  else
    current_hash="$(_content_hash "$vendored_dir")"
    if [[ "$current_hash" != "$recorded_hash" ]]; then
      local_modified=1
      local_mod_note="skills/$name/ differs from last snapshot"
    fi
  fi

  # ── 2. Git upstream check ────────────────────────────────────────────────
  git_behind=0
  git_note=""
  if [[ ! -d "$clone_dir/.git" ]]; then
    git_note="(sources/$source_name not cloned yet — run 'shuk skills update $name' to clone)"
    n_no_clone=$((n_no_clone + 1))
  else
    if [[ "$DO_FETCH" -eq 1 ]]; then
      git -C "$clone_dir" fetch --quiet origin 2>/dev/null || true
    fi
    origin_commit="$(git -C "$clone_dir" rev-parse "origin/${branch:-main}" 2>/dev/null || echo "")"
    if [[ -n "$origin_commit" && -n "$recorded_commit" && "$recorded_commit" != "null" ]]; then
      if [[ "$origin_commit" != "$recorded_commit" ]]; then
        behind_count="$(git -C "$clone_dir" rev-list "${recorded_commit}..origin/${branch:-main}" --count 2>/dev/null || echo "?")"
        git_behind=1
        git_note="${behind_count} commits ahead on origin/${branch:-main} (${recorded_commit:0:8}→${origin_commit:0:8})"
      fi
    fi
  fi

  # ── Summarise ────────────────────────────────────────────────────────────
  if [[ "$local_modified" -eq 1 && "$git_behind" -eq 1 ]]; then
    err "CONFLICT  [$name]"
    echo "          local edits detected AND upstream git has new commits"
    [[ -n "$local_mod_note" ]] && echo "          local: $local_mod_note"
    [[ -n "$git_note" ]]       && echo "          git:   $git_note"
    n_conflict=$((n_conflict + 1))
  elif [[ "$local_modified" -eq 1 ]]; then
    warn "LOCAL-MOD [$name]"
    [[ -n "$local_mod_note" ]] && echo "          $local_mod_note"
    n_local_mod=$((n_local_mod + 1))
  elif [[ "$git_behind" -eq 1 ]]; then
    info "GIT-AHEAD [$name]  — run 'shuk skills update $name' to pull"
    echo "          git: $git_note"
    n_git_behind=$((n_git_behind + 1))
  else
    ok "current   [$name]  (updated $last_synced)"
    [[ -n "$git_note" ]] && echo "          $git_note"
    n_current=$((n_current + 1))
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  warn "No source-tracked skills found in $DEST"
  exit 0
fi

echo ""
echo "Summary:"
[[ "$n_current"    -gt 0 ]] && ok   "$n_current up to date"
[[ "$n_git_behind" -gt 0 ]] && info "$n_git_behind with upstream git commits available"
[[ "$n_local_mod"  -gt 0 ]] && warn "$n_local_mod with local modifications"
[[ "$n_conflict"   -gt 0 ]] && err  "$n_conflict conflicts (local edits + upstream update — manual resolution needed)"
[[ "$n_no_clone"   -gt 0 ]] && info "$n_no_clone not yet cloned (git upstream unknown — run 'shuk skills update' to clone)"
[[ "$DO_FETCH" -eq 0 && "$n_no_clone" -eq 0 ]] && info "Tip: run 'shuk skills check --fetch' to also check for new upstream commits"
