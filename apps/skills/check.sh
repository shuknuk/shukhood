#!/usr/bin/env bash
# shuk skills check — read-only status report for all source-tracked skills.
#
# For each source-tracked skill, checks three things:
#   1. Local mods:    has skills/<name>/ been edited since last sync?
#   2. Hermes update: has ~/.hermes/skills/<name>/ changed? (Hermes updated its install)
#   3. Git upstream:  does the source git repo have commits beyond Hermes' copy?
#      (requires network; pass --no-fetch to skip git fetch)
#
# No files are modified.
set -euo pipefail

SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"

DEST="$SHUK_ROOT/skills"
DO_FETCH=1

for arg in "$@"; do
  [[ "$arg" == "--no-fetch" ]] && DO_FETCH=0
done

# ---------------------------------------------------------------------------
# Content hash (same function as sync.sh)
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
n_hermes_update=0
n_git_behind=0
n_local_mod=0
n_conflict=0

for prov_file in "$DEST"/*/.shukhood-source.json; do
  [[ -f "$prov_file" ]] || continue

  name="$(jq -r '.skill'             "$prov_file" 2>/dev/null)"
  stype="$(jq -r '.source_type'      "$prov_file" 2>/dev/null)"
  [[ "$stype" != "source-tracked" ]] && continue

  found_any=1
  source_name="$(jq -r '.source_name'      "$prov_file" 2>/dev/null)"
  repo_path="$(jq -r '.source_repo_path'   "$prov_file" 2>/dev/null)"
  branch="$(jq -r '.source_branch'         "$prov_file" 2>/dev/null)"
  recorded_commit="$(jq -r '.source_commit' "$prov_file" 2>/dev/null)"
  recorded_hash="$(jq -r '.content_hash'   "$prov_file" 2>/dev/null)"
  last_synced="$(jq -r '.last_synced'      "$prov_file" 2>/dev/null)"
  synced_from="$(jq -r '.synced_from'      "$prov_file" 2>/dev/null)"

  vendored_dir="$DEST/$name"
  hermes_dir="$synced_from"

  # ── 1. Local modification check ──────────────────────────────────────────
  local_modified=0
  if [[ -z "$recorded_hash" || "$recorded_hash" == "null" ]]; then
    local_mod_note="(no hash recorded — run 'shuk skills sync' to baseline)"
  else
    current_hash="$(_content_hash "$vendored_dir")"
    if [[ "$current_hash" != "$recorded_hash" ]]; then
      local_modified=1
      local_mod_note="skills/$name/ differs from last-sync snapshot"
    else
      local_mod_note=""
    fi
  fi

  # ── 2. Hermes install update check ───────────────────────────────────────
  hermes_updated=0
  hermes_note=""
  if [[ -d "$hermes_dir" ]]; then
    hermes_hash="$(_content_hash "$hermes_dir")"
    # If Hermes' installed copy differs from what we vendored, it has been updated
    # (compare Hermes hash against our vendored hash — they should match if in sync)
    if [[ -n "$recorded_hash" && "$recorded_hash" != "null" && "$hermes_hash" != "$recorded_hash" ]]; then
      hermes_updated=1
      hermes_note="~/.hermes/skills/$name/ has changed since last sync"
    fi
  else
    hermes_note="(Hermes install dir not found: $hermes_dir)"
  fi

  # ── 3. Git upstream check (optional fetch) ───────────────────────────────
  git_behind=0
  git_note=""
  if [[ -d "$repo_path/.git" ]]; then
    if [[ "$DO_FETCH" -eq 1 ]]; then
      git -C "$repo_path" fetch --quiet origin 2>/dev/null || true
    fi
    origin_commit="$(git -C "$repo_path" rev-parse "origin/${branch}" 2>/dev/null || echo "")"
    if [[ -n "$origin_commit" && -n "$recorded_commit" && "$recorded_commit" != "null" ]]; then
      if [[ "$origin_commit" != "$recorded_commit" ]]; then
        # Count commits from recorded commit to current origin HEAD
        behind_count="$(git -C "$repo_path" rev-list "${recorded_commit}..origin/${branch}" --count 2>/dev/null || echo "?")"
        git_behind=1
        git_note="${behind_count} commits ahead on origin/${branch} (${recorded_commit:0:8}→${origin_commit:0:8})"
      fi
    fi
  fi

  # ── Summarise ────────────────────────────────────────────────────────────
  if [[ "$local_modified" -eq 1 && "$hermes_updated" -eq 1 ]]; then
    err "CONFLICT  [$name]"
    echo "          local edits detected AND Hermes has an update available"
    [[ -n "$local_mod_note" ]]  && echo "          local:   $local_mod_note"
    [[ -n "$hermes_note" ]]     && echo "          hermes:  $hermes_note"
    [[ -n "$git_note" ]]        && echo "          git:     $git_note"
    n_conflict=$((n_conflict + 1))
  elif [[ "$local_modified" -eq 1 ]]; then
    warn "LOCAL-MOD [$name]"
    [[ -n "$local_mod_note" ]] && echo "          $local_mod_note"
    [[ -n "$git_note" ]]       && echo "          git: $git_note"
    n_local_mod=$((n_local_mod + 1))
  elif [[ "$hermes_updated" -eq 1 ]]; then
    info "UPDATE    [$name]  — run 'shuk skills update $name' to pull"
    [[ -n "$hermes_note" ]] && echo "          $hermes_note"
    [[ -n "$git_note" ]]    && echo "          git: $git_note"
    n_hermes_update=$((n_hermes_update + 1))
  elif [[ "$git_behind" -eq 1 ]]; then
    info "GIT-AHEAD [$name]  — upstream has commits Hermes hasn't installed yet"
    echo "          git: $git_note"
    n_git_behind=$((n_git_behind + 1))
  else
    ok "current   [$name]  (synced $last_synced)"
    n_current=$((n_current + 1))
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  warn "No source-tracked skills found in $DEST — run 'shuk skills sync' first"
  exit 0
fi

echo ""
echo "Summary:"
[[ "$n_current"       -gt 0 ]] && ok    "$n_current up to date"
[[ "$n_hermes_update" -gt 0 ]] && info  "$n_hermes_update with Hermes updates available"
[[ "$n_git_behind"    -gt 0 ]] && info  "$n_git_behind where upstream git is ahead of Hermes"
[[ "$n_local_mod"     -gt 0 ]] && warn  "$n_local_mod with local modifications (no upstream update pending)"
[[ "$n_conflict"      -gt 0 ]] && err   "$n_conflict conflicts (local edits + upstream update — manual resolution needed)"
