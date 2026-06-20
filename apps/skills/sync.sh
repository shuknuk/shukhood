#!/usr/bin/env bash
# shuk skills sync — vendor ~/.hermes/skills/ into skills/ in the repo.
# Writes .shukhood-source.json alongside each copied skill dir,
# including source_commit and content_hash for Phase 3 change detection.
set -euo pipefail

SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"

HERMES_SKILLS="$HOME/.hermes/skills"
DEST="$SHUK_ROOT/skills"
SOURCES_JSON="$HOME/.hermes/manual-skill-sources.json"

mkdir -p "$DEST"

# ---------------------------------------------------------------------------
# Compute a stable content hash of a directory, excluding provenance/OS files.
# Works on macOS bash 3.2 (no associative arrays, no sort -z).
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

COPIED=0

for skill_dir in "$HERMES_SKILLS"/*/; do
  name="$(basename "$skill_dir")"
  [[ "$name" == .* ]] && continue
  [[ ! -d "$skill_dir" ]] && continue

  dest_skill="$DEST/$name"

  rsync -a --delete \
    --exclude='.DS_Store' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.git/' \
    "$skill_dir" "$dest_skill/" 2>/dev/null

  # ---------------------------------------------------------------------------
  # Determine provenance from manual-skill-sources.json
  # ---------------------------------------------------------------------------
  source_type="local"
  source_name=""
  remote=""
  source_repo_path=""
  source_branch=""
  source_commit=""

  if [[ -f "$SOURCES_JSON" ]] && command -v jq >/dev/null 2>&1; then
    match="$(jq -r --arg n "$name" '
      .sources[]
      | select((.dest_category | split("/")[0]) == $n)
      | [.name, (.remote // ""), (.repo_path // ""), (.branch // "main")] | @tsv
    ' "$SOURCES_JSON" 2>/dev/null | head -1)"

    if [[ -n "$match" ]]; then
      source_type="source-tracked"
      source_name="$(printf '%s' "$match" | cut -f1)"
      remote="$(printf '%s' "$match" | cut -f2)"
      source_repo_path_raw="$(printf '%s' "$match" | cut -f3)"
      source_branch="$(printf '%s' "$match" | cut -f4)"
      # Expand leading ~ in repo path
      source_repo_path="${source_repo_path_raw/#\~/$HOME}"
      # Record git commit from the source repo clone
      if [[ -d "$source_repo_path/.git" ]]; then
        source_commit="$(git -C "$source_repo_path" rev-parse HEAD 2>/dev/null || echo "")"
      fi
    fi
  fi

  # ---------------------------------------------------------------------------
  # Content hash — fingerprint of vendored files at this moment
  # ---------------------------------------------------------------------------
  content_hash="$(_content_hash "$dest_skill")"

  last_synced="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  cat > "$dest_skill/.shukhood-source.json" <<EOF
{
  "skill": "$name",
  "source_type": "$source_type",
  "source_name": "$source_name",
  "remote": "$remote",
  "source_repo_path": "$source_repo_path",
  "source_branch": "$source_branch",
  "source_commit": "$source_commit",
  "synced_from": "$skill_dir",
  "last_synced": "$last_synced",
  "content_hash": "$content_hash"
}
EOF

  COPIED=$((COPIED + 1))
done

ok "Synced $COPIED skills → $DEST"
info "Run 'shuk skills serve' to start the MCP server."
