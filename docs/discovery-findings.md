# Phase 0 — Discovery Findings

_Investigated: 2026-06-19. All paths/commands cited so you can spot-check._

---

## Q1 — Skill provenance

### How Hermes tracks skills

Hermes uses two tracking mechanisms, neither of which embeds metadata inside the installed skill dir itself:

1. **`~/.hermes/manual-skill-sources.json`** — explicit source registry with git repo URL, branch, install mode, and dest category for each source group. Hermes clones repos into `~/.hermes/sources/<name>/` and flattens/copies skills into `~/.hermes/skills/<dest_category>/`. State (commit lag, changed flag) is persisted per-source in `~/.hermes/manual-skill-sources.state.json`.
2. **`~/.hermes/skills/.hub/`** — hub marketplace tracking. `taps.json` is currently `{"taps": []}` — no hub taps installed.
3. **`~/.hermes/skills/.bundled_manifest`** — exists but is empty (0 bytes of parseable JSON) — nothing bundled is explicitly tracked here right now.

No individual skill directory contains a `.skillmeta`, `source.json`, `.git`, or any other per-skill provenance file. Source of truth is the top-level tracking files only.

### Skill provenance table

**Source-tracked** (origin URL known via `manual-skill-sources.json`):

| Installed dir(s) | Source name | Origin URL |
|---|---|---|
| `medical-research/` | medical-research-skills | https://github.com/aipoch/medical-research-skills |
| `awesome-design-skills/` | awesome-design-skills | https://github.com/bergside/awesome-design-skills |
| `awesome-claude-skills-index/` | awesome-claude-skills-index | https://github.com/travisvn/awesome-claude-skills |
| `docs/` | anthropic-skills-docs | https://github.com/anthropics/skills (subset) |
| `design-skills/anthropic/` | anthropic-skills-design | https://github.com/anthropics/skills (subset) |
| `productivity/anthropic/` | anthropic-skills-productivity | https://github.com/anthropics/skills (subset) |
| `software-development/anthropic/` | anthropic-skills-development | https://github.com/anthropics/skills (subset) |
| `media/anthropic/` | anthropic-skills-media | https://github.com/anthropics/skills (subset) |
| `superpowers/core/` | superpowers-core | https://github.com/obra/superpowers |
| `superpowers/community/` | superpowers-community | https://github.com/obra/superpowers-skills |
| `superpowers/lab/` | superpowers-lab | https://github.com/obra/superpowers-lab |
| `ios/` | ios-simulator-skill | https://github.com/conorluddy/ios-simulator-skill |
| `security/ffuf/` | ffuf-claude-skill | https://github.com/jthack/ffuf_claude_skill |
| `browser-automation/` | playwright-skill | https://github.com/lackeyjb/playwright-skill |
| `design-skills/d3js/` | claude-d3js-skill | https://github.com/chrisvoncsefalvay/claude-d3js-skill |
| `scientific-skills/` | claude-scientific-skills | https://github.com/K-Dense-AI/claude-scientific-skills |
| `design-skills/web-assets/` | web-asset-generator | https://github.com/alonw0/web-asset-generator |
| `autonomous-ai-agents/loki*` | loki-mode-* | https://github.com/asklokesh/claudeskill-loki-mode |
| `security/trailofbits/` | trailofbits-security-skills | https://github.com/trailofbits/skills |
| `design-skills/frontend-slides/` | frontend-slides | https://github.com/zarazhangrui/frontend-slides |
| `mobile-development/expo/` | expo-skills | https://github.com/expo/skills |
| `skill-building/skill-seekers/` | skill-seekers | https://github.com/yusufkaraaslan/Skill_Seekers |
| `anthropic-cookbooks/` | anthropic-claude-cookbooks | https://github.com/anthropics/claude-cookbooks |
| `writing-content/` | writing-content-upstreams | (source dir present, remote URL TBD) |

**Unknown provenance** — not in `manual-skill-sources.json`, hub taps empty, bundled manifest empty. Likely installed directly by user via `hermes skills add` or came bundled with Hermes at install time:

`apple`, `claude-fable-5`, `creative`, `data-science`, `devops`, `diagramming`, `dogfood`, `domain`, `email`, `gaming`, `gifs`, `github`, `gsap-core`, `gsap-frameworks`, `gsap-performance`, `gsap-plugins`, `gsap-react`, `gsap-scrolltrigger`, `gsap-timeline`, `gsap-utils`, `gstack`, `gstack-autoplan`, `gstack-benchmark`, `gstack-benchmark-models`, `gstack-browse`, `gstack-canary`, `gstack-careful`, `gstack-claude`, `gstack-context-restore`, `gstack-context-save`, `gstack-cso`, `gstack-design-consultation`, `gstack-design-html`, `gstack-design-review`, `gstack-design-shotgun`, `gstack-devex-review`, `gstack-document-generate`, `gstack-document-release`, `gstack-freeze`, `gstack-guard`, `gstack-health`, `gstack-investigate`, `gstack-ios-clean`, `gstack-ios-design-review`, `gstack-ios-fix`, `gstack-ios-qa`, `gstack-ios-sync`, `gstack-land-and-deploy`, `gstack-landing-report`, `gstack-learn`, `gstack-make-pdf`, `gstack-office-hours`, `gstack-open-gstack-browser`, `gstack-pair-agent`, `gstack-plan-ceo-review`, `gstack-plan-design-review`, `gstack-plan-devex-review`, `gstack-plan-eng-review`, `gstack-plan-tune`, `gstack-qa`, `gstack-qa-only`, `gstack-retro`, `gstack-review`, `gstack-scrape`, `gstack-setup-browser-cookies`, `gstack-setup-deploy`, `gstack-setup-gbrain`, `gstack-ship`, `gstack-skillify`, `gstack-spec`, `gstack-sync-gbrain`, `gstack-unfreeze`, `gstack-upgrade`, `inference-sh`, `master-skill-index`, `mcp`, `mlops`, `note-taking`, `red-teaming`, `research`, `smart-home`, `social-media`, `voicebox`, `yuanbao`

**Total top-level skill dirs: 103** (including hidden metadata dirs `.hub`, `.archive`, `.bundled_manifest`, etc.)  
**Actual skill dirs: ~90** (excluding hidden/metadata)  
**Source-tracked: ~24 source groups → ~18 top-level skill category dirs**  
**Unknown provenance: ~70 top-level dirs** (gstack-* family alone is 35+)

### Action needed from user before Phase 1

For the `unknown` group: do you know whether the `gstack` and similar skills came from a specific upstream repo, or were they authored locally/by you? This affects whether we attempt upstream sync for them. If you don't know, the safe default is to treat them as `local-only` (vendor as-is, no sync).

---

## Q2 — Sync direction and conflict handling

**Proposed default (needs your confirmation):**

- **Source-tracked skills**: one-way, upstream → Shukhood's vendored `skills/` copy. Hermes already does this via the `sources/` git repos; Shukhood would read from those same git checkouts rather than re-cloning. Never push back to upstream.
- **Unknown-provenance skills**: vendored as-is from `~/.hermes/skills/`, marked `"source": "local"` in provenance file. No sync attempted. Shukhood is the source of truth for these copies.
- **Conflict handling**: if a vendored copy has local edits AND upstream has new commits — **detect and warn, do not auto-overwrite**. The `shuk skills check` command (Phase 3) would surface this; `shuk skills update <name>` would require explicit invocation. This is the assumption I'll build to unless you say otherwise.

**Please confirm (or correct) the conflict default above before Phase 1 starts.**

---

## Q3 — MCP exposure shape

### Scan results

Scanned `~/.hermes/skills/` up to 4 levels deep for `*.py` and `*.sh` files.

**Scripts found:**

| Parent skill dir | Script files | Notes |
|---|---|---|
| `gstack/` | `bin/*.sh`, `scripts/*.sh`, `supabase/*.sh` | Build/utility scripts for gstack workflows; called by agent, not standalone tools |
| `medical-research/litbase/` | `lookup_paper.py`, `rename_pdfs.py`, `recommend.py`, `install.sh` | Data retrieval/manipulation scripts |
| `medical-research/reference-search/` | `run_search.py`, `run_query.py` | Search helpers |
| `medical-research/experiment-detail-comparator/` | `run_comparison.py` | Comparison script |
| `medical-research/ppt/` | `build_html.py`, `convert_to_pptx.py`, `validate_data.py` | PPTX generation pipeline |
| `medical-research/paper-tweet-generator/` | `extract_*.py` | PDF extraction helpers |
| `medical-research/torchdrug-english/` | `translate_md.py` | Translation helper |
| `medical-research/unstructured-medical-text-miner/` | `example.py` | Example/demo script |
| `anthropic-cookbooks/cookbook-*/` | `dcf_model.py`, `sensitivity_analysis.py`, `interpret_ratios.py`, `calculate_ratios.py`, `validate_notebook.py`, `apply_brand.py`, `validate_brand.py` | Cookbook example scripts |
| `productivity/ocr-and-documents/` | `scripts/extract_pymupdf.py`, `scripts/extract_marker.py` | OCR extraction |
| `ios/ios-simulator-skill/` | `scripts/*.py` (7 files) | iOS simulator automation |

**Counts:**
- **Resource-only** (markdown/SKILL.md only, no runnable scripts): ~80+ top-level dirs
- **Has runnable scripts** (nested within): ~8 top-level category dirs containing scripted sub-skills

### Assessment for tool promotion candidates (Phase 2 review)

Scripts split into two groups:

1. **Workflow helpers** (`gstack/bin/*.sh`, `gstack/scripts/*.sh`): these are shell scripts that the agent calls as part of multi-step workflows. They're not standalone operations — they assume project context. **Do not promote to MCP tools.**

2. **Computation scripts** (medical-research/*.py, ios/*.py, anthropic-cookbooks/*.py): these take inputs and produce outputs. Some are plausible tool promotion candidates:
   - `litbase/lookup_paper.py` — paper lookup by query → candidate
   - `reference-search/run_search.py` — search runner → candidate  
   - `ios-simulator-skill/scripts/*.py` — simulator control → candidates
   - Others (ppt/build_html.py etc.) are pipeline steps, not standalone → skip

**Recommend reviewing these ~5-8 script files in Phase 2 for tool promotion.** All others stay resource-only.

---

## Q4 — Existing Shukhood structure

### Repo layout

```
shukhood/
  bin/shuk              # main CLI dispatcher — case statement routing
  core/
    banner.sh           # shuk_banner() function
    logging.sh          # ok/warn/err/info log helpers
    doctor.sh           # shuk doctor — checks tools, auth, profiles
    backup.sh           # shuk backup — delegates to apps/hermes/backup.sh
    colors.sh           # ANSI color vars
    secrets.sh          # secret loading
  shared/
    skills/registry.yaml  # skill registry (content TBD)
    mcp/registry.yaml     # MCP registry
  apps/
    hermes/
      launch.sh         # shuk hermes — profile+skills launch
      setup.sh          # shuk hermes setup
      backup.sh         # shuk hermes backup
      doctor.sh         # shuk hermes doctor
      mcp.sh            # shuk mcp
  docs/                 # markdown docs (architecture, backup-policy, etc.)
  secrets/.env.example  # secret template
  .shukhood.yml         # project config
  setup.sh              # install/link shuk command
```

### CLI dispatch pattern

`bin/shuk` uses a `case "$cmd"` block. Adding `skills` is a one-liner:
```bash
skills) shift; "$SHUK_ROOT/apps/skills/skills.sh" "$@" ;;
```
New functionality lives in `apps/skills/` (matching the `apps/hermes/` convention) with `skills.sh` routing sub-commands (`serve`, `sync`, `check`, `update`).

### Python environment decision

**The repo is 100% shell today.** FastMCP (needed for the MCP server) will introduce the first Python dependency.

**Decision: self-contained `uv`-managed environment in `apps/skills/`**

Rationale:
- `uv` is already listed as a required tool in `.shukhood.yml` — it's present on this machine
- Keeps Python isolated from the shell-only core; doesn't contaminate repo root with a `pyproject.toml`
- Follows the `apps/<agent>/` convention for app-specific code
- `apps/skills/server.py` + `apps/skills/pyproject.toml` + `uv venv` at `apps/skills/.venv/`
- The `shuk skills serve` shell wrapper activates the venv then runs `python server.py`

No repo-wide Python toolchain, no root-level `pyproject.toml`.

---

## Q5 — Target MCP clients on this machine

| Client | Present | Version | MCP registration command | Config file |
|---|---|---|---|---|
| **Claude Code** | ✅ | 2.1.183 | `claude mcp add <name> -- <cmd>` | `~/.claude/settings.json` |
| **Codex** | ✅ | 0.134.0 | `codex mcp add` | `~/.codex/config.toml` → `[mcp_servers.*]` block |
| **Hermes** | ✅ | 0.16.0 | Edit `~/.hermes/config.yaml` → `mcp_servers:` key | `~/.hermes/config.yaml` (already has context7, git, magicui) |
| **Antigravity** | ❌ | — | — | — |
| **OpenCode** | ❌ | — | — | — |

### Notes per client

**Claude Code**: standard `claude mcp add shukhood -- shuk skills serve`. Config lands in `~/.claude/settings.json` under `mcpServers`.

**Codex**: uses `codex mcp add`. Config goes into `~/.codex/config.toml` as:
```toml
[mcp_servers.shukhood]
command = "shuk"
args = ["skills", "serve"]
```

**Hermes**: add to `~/.hermes/config.yaml`:
```yaml
mcp_servers:
  shukhood:
    command: shuk
    args: [skills, serve]
    enabled: true
```
Shukhood should NOT auto-write to `~/.hermes/config.yaml` — that's the user's live config. The `shuk connect hermes` command (Phase 4) should print the block for the user to paste, or use `hermes config set` if that CLI exists.

---

## Summary for Phase 1 go/no-go

Before I write any implementation code, **please confirm two things**:

1. **Unknown-provenance skills** (`gstack-*`, `dogfood`, `voicebox`, etc.): treat as `local-only`, vendor as-is with no upstream sync attempted. Correct?

2. **Conflict default**: detect-and-warn (do not auto-overwrite a locally-modified vendored skill when upstream has changes). Correct?

If both are confirmed, Phase 1 is ready to start.
