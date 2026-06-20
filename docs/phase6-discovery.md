# Phase 6 — Discovery Findings

_Date: 2026-06-20. Stop after reading this; confirm before Phase 1 begins._

---

## D1 — Diff: `~/.hermes/skills/` vs repo `skills/`

**Result: migration scope is essentially zero.**

- `~/.hermes/skills/` has 103 entries; repo `skills/` has 102.
- The single difference: `~/.hermes/skills/gsap-llms.txt` — a **plain text file** (not a directory) sitting loose in the skills root. It is not a skill. `sync.sh` correctly skips it (its loop only processes directories: `for skill_dir in "$HERMES_SKILLS"/*/`).
- All 102 skill directories are identical between both locations. The last sync ran on **2026-06-19** (skills/ mtimes confirm).

**Conclusion:** No skills were added to `~/.hermes/skills/` since the last sync. The "one-time migration" in Phase 1 only needs to:
1. Copy `gsap-llms.txt` if we want it (it's not a skill — recommendation: skip it).
2. Migrate `manual-skill-sources.json` (see D2).
3. Decide on `~/.hermes/sources/` (see D2).
4. Update provenance files (change `synced_from` away from hermes path).

---

## D2 — "Other important things" beyond skill directories

### `~/.hermes/manual-skill-sources.json` — **MUST MIGRATE**

This file maps 25 source-tracked skill groups to their upstream git URLs. `sync.sh` reads it at `$SOURCES_JSON` (line 12) to classify skills and write provenance. `check.sh` and `update.sh` read the `source_repo_path` field that sync.sh writes into each skill's `.shukhood-source.json`.

Once `sync.sh` is gone (Phase 2), this file's role changes: it becomes the canonical record of which skill groups have upstream git remotes, used by `check.sh`/`update.sh` for git-upstream checks and by documentation.

**Action:** Copy `~/.hermes/manual-skill-sources.json` into the repo. Logical home: `apps/skills/skill-sources.json` (alongside the other skills machinery). Update all references.

### `~/.hermes/sources/` — **LEAVE IN PLACE (for now)**

These are 20 git clones backing the source-tracked groups. `check.sh`'s git-upstream check reads `repo_path` from each skill's `.shukhood-source.json` — that field currently points to paths like `~/.hermes/sources/medical-research-skills`.

After Phase 1 migration, the provenance `repo_path` values will still point here and `check.sh`/`update.sh` will still work as long as `~/.hermes/sources/` exists (Hermes maintains these clones). 

What changes in Phase 2: `update.sh` currently reads from `synced_from` (the `~/.hermes/skills/<name>/` path) to rsync updates into the repo. Once `~/.hermes/skills/` is no longer the source of truth, `update.sh`'s update logic needs to rsync directly from the git clone in `~/.hermes/sources/` instead of the Hermes-installed copy. This is a surgical change to `update.sh`, not a reason to move the git clones.

**Recommendation:** Leave `~/.hermes/sources/` where it is. Hermes manages it; we read it. Update `update.sh` in Phase 2 to pull from source git clones directly instead of via the Hermes-installed copy.

### `~/.hermes/config.yaml` (skills-relevant portions) — **NOTHING TO MIGRATE**

- `skills.external_dirs: []` — empty. Hermes loads only from its own `~/.hermes/skills/` (built-in, not configurable to disable without source changes).
- No per-skill config lives in the global config. All skill-local config (e.g. API keys in `config.json` files) lives inside individual skill directories, which are already in the repo.

### Hermes curator state — **SKIP**

`curator: enabled: true` in Hermes config. Hermes keeps internal usage stats per skill in its own state DB. This is Hermes-internal bookkeeping; it doesn't affect skill content and doesn't need to migrate.

### `.shukhood-source.json` per skill — **ALREADY IN REPO**

These live inside each skill directory and travel with the skills. No separate migration needed.

---

## D3 — All `~/.hermes` references in the codebase

Every line that currently reads from or writes to `~/.hermes` paths, grouped by what happens to it:

### **Remove entirely (launcher removal, Phase 4)**
| File | What it does |
|---|---|
| `apps/hermes/launch.sh` | Entire file — dispatches `shuk hermes *` subcommands |
| `apps/hermes/setup.sh:16-36` | Creates Hermes profile, symlinks skills from `~/.hermes/skills/` |
| `apps/hermes/backup.sh:8` | References `~/.hermes/profiles/shukhood` |
| `apps/hermes/doctor.sh:7` | References `~/.hermes/profiles/shukhood` |
| `core/doctor.sh:18-23` | Hermes profile/gstack skill checks |

### **Update (sync→standalone, Phase 2)**
| File | Line(s) | Change |
|---|---|---|
| `apps/skills/server.py` | 18, 27-29 | Remove `_HERMES` fallback; `_resolve_skills_dir()` reads only `_VENDORED` |
| `apps/skills/sync.sh` | entire file | Remove or rename to `import-legacy` (or just delete) |
| `apps/skills/skills.sh` | 55, 64, 80 | Remove hermes count from status; remove warn about fallback; remove `sync` help line |
| `apps/skills/check.sh` | 6, 93 | Remove "Hermes update" check path (D2: `synced_from` no longer points to `~/.hermes/skills/`) — reframe as just local-mod + git-upstream |
| `apps/skills/update.sh` | 91 | Update error message; change rsync source from `synced_from` (hermes path) to git clone in `~/.hermes/sources/` |

### **Keep as-is (MCP connect flow)**
| File | What it does |
|---|---|
| `apps/connect/connect.sh:18,35,150,155,160,165,226` | Checks/reads `~/.hermes/config.yaml` to register shukhood MCP server. This is the correct connect flow — keep it. |
| `core/secrets.sh:8,17,18` | References `~/.hermes/.env` for secrets. Valid — Hermes stores env there; `shuk secrets` syncs to it. |

---

## D4 — Hermes skill loading vs. MCP server coexistence

**Current state:** `~/.hermes/config.yaml` has `skills.external_dirs: []` and no `shukhood` entry in `mcp_servers:` (the YAML from `shuk connect hermes` has not been pasted in yet, per config inspection).

**Key architectural distinction:** Hermes has two separate namespaces:
1. **Native skills** (`~/.hermes/skills/`, profile skills, `external_dirs`) — these are SKILL.md files Hermes injects into its own system prompt for routing/behavior. Hermes always loads from `~/.hermes/skills/` by default; there is no config knob to disable this built-in path.
2. **MCP tools** (`mcp_servers:` config) — these expose external MCP server capabilities as tool calls to the agent. MCP resources (like shukhood's skill://* URIs) appear as readable resources, not as injected skills.

**Consequence:** Once Hermes connects to shukhood via MCP:
- Hermes still has its native `~/.hermes/skills/` loaded (it can't be turned off without modifying Hermes itself).
- Shukhood skills are also available as MCP resources (a different access mechanism).
- These do **not** conflict — they serve different purposes. Native skills control Hermes's routing behavior; MCP resources are data the agent can read on demand.
- There is no duplication risk in the traditional sense, because Hermes doesn't auto-inject MCP resources the way it does native skills.

**Recommendation for Phase 3:** The instruction to "disable Hermes's local skill loading" cannot be done via config. The practical answer is: it doesn't need to be. After the migration, `~/.hermes/skills/` remains populated (we don't delete it until Phase 5). Hermes loads it as before for its own routing. The MCP side is additive. What changes is where skills live canonically and what agents use them as.

When/if the user archives `~/.hermes/skills/` (Phase 5), Hermes's native skill injection will lose those skills — but by then Hermes should be using the MCP resource access path instead. Document this clearly in `shuk connect hermes` output.

---

## D5 — Agy

- **Installed:** yes, `agy --version` → `1.0.10`
- **Config found:** none. No `~/.agy/`, no `~/.config/agy/`, no `~/Library/Application Support/agy`, no `~/Library/Preferences/agy.*`.
- `agy` requires a TTY to start, preventing automated config inspection.
- **Action:** Leave agy as a placeholder in `shuk connect`. Add a `--list` entry showing it as "detected, config location unknown." Unblock Phase 3 from needing this resolved.

---

## Summary — what Phase 1 actually needs to do

1. **Copy `~/.hermes/manual-skill-sources.json` → `apps/skills/skill-sources.json`** (MUST). Update `sync.sh`'s `SOURCES_JSON` reference as part of Phase 2's sync removal.
2. **Skip `gsap-llms.txt`** — not a skill, not worth vendoring.
3. **No skill directory content needs copying** — all 102 dirs are already in `skills/`.
4. **Update `.shukhood-source.json` provenance in each skill** — change `synced_from` from `~/.hermes/skills/<name>/` to indicate canonical repo path. (Could be done as part of Phase 2 when sync is removed, since it's a metadata change not a content migration.)

The heavy lifting is in Phases 2 and 4 (removing sync and the launcher), not Phase 1.

---

## Open questions before proceeding

1. **`shuk skills update` after migration:** The current `update.sh` rsyncs from `~/.hermes/skills/<name>/` (the Hermes-installed copy). After Phase 2, there's no Hermes-installed copy to rsync from. The replacement behavior should be: pull directly from the git clone in `~/.hermes/sources/<repo-name>/`. This changes `update.sh` from "copy what Hermes installed" to "pull from upstream git clone." Confirm this is the right behavior, or whether `shuk skills update` should instead just do `git pull` in the source clone followed by a re-copy.

2. **`shuk skills check` after migration:** The "Hermes update" check (does `~/.hermes/skills/<name>/` differ from our snapshot?) becomes meaningless. The remaining checks are: local modifications (same as now) and git upstream ahead (same as now, reading from `~/.hermes/sources/`). Confirm it's okay to remove the Hermes-update check and keep only local-mod + git-ahead.

3. **`manual-skill-sources.json` location:** Recommend `apps/skills/skill-sources.json`. Confirm.
