# $HUKHOOD

Shukhood is a shared skills MCP server. It stores a skill library canonically in `skills/` with provenance tracking, then exposes all of it over the Model Context Protocol so any MCP-capable agent — Claude Code, Codex, Hermes, Agy, or others — can read from a single source of truth.

---

## Quick start

```bash
./setup.sh                # first time only: install shuk command
shuk connect --all        # register with every present MCP client
# clients launch `shuk skills serve` automatically via MCP
```

---

## Skills MCP server

### Commands

```bash
shuk skills serve                # start the MCP server over stdio
shuk skills status               # show server config, venv path, and skill counts
shuk skills check                # report status for all source-tracked skills
shuk skills check --no-fetch     # same, skip git fetch (no network)
shuk skills update <name>        # update one source-tracked skill from upstream git
shuk skills update --all         # update all source-tracked skills from upstream git
```

### How it works

**Skills directory.** All skills live canonically in `skills/` inside this repo. The `skills/` tree is gitignored (content is not committed — only `.gitkeep` and the tooling in `apps/skills/` are tracked). Override the path with `SHUKHOOD_SKILLS_DIR=<path>`.

**Provenance tracking.** Each skill directory contains a `.shukhood-source.json` file recording the source group name, remote URL, git commit, and a SHA256 content hash. This enables change detection and conflict prevention.

**Category collapse.** Skills are organized as flat dirs (`skill://superpowers`) or nested dirs (`skill://medical-research/<subskill>`). Any category containing more than 10 sub-skills is collapsed: `list_resources()` exposes one `skill://<category>` index resource listing all sub-skill names and descriptions. Individual sub-skills are readable via template URI `skill://<category>/<subname>`. The threshold is `CATEGORY_THRESHOLD = 10` in `apps/skills/server.py`.

**Resource count.** With 102 skill dirs containing ~925 individual sub-skills, `list_resources()` returns 138 resources. Every sub-skill is still readable on demand via its URI.

**Provenance model.** Skills fall into two tiers:
- **Source-tracked** — 25 source groups with known git remotes in `apps/skills/skill-sources.json`. These participate in `shuk skills check` and `shuk skills update`, which pull directly from the upstream git clones in `~/.hermes/sources/` (Hermes manages those clones).
- **Local-only** — everything else (~70+ dirs: `gstack-*`, `dogfood`, `voicebox`, etc.). No upstream sync attempted. This repo is the source of truth for these.

**Update flow.** `shuk skills update` fetches the upstream git clone, checks for local modifications and new upstream commits, then rsyncs the updated content. Decision matrix: local edits + upstream ahead = conflict (stop, report, touch nothing); local edits + no upstream change = no-op; no local edits + upstream ahead = update; both current = no-op.

**Content hash.** Change detection uses SHA256 of all file paths + contents in a directory, excluding `.shukhood-source.json` and `.DS_Store`. Computed relative to the directory root so hashes are path-independent.

---

## Client connections

### Quick connect

```bash
shuk connect --list              # show registered / not-registered per client
shuk connect --all               # register with every present client
shuk connect claude              # Claude Code only
shuk connect codex               # Codex only
shuk connect hermes              # print YAML block to paste into ~/.hermes/config.yaml
```

`shuk connect` is idempotent — re-running on an already-registered client is a no-op.

### Current connection status

All three present clients are connected and verified (JSON-RPC `initialize` → `resources/list` round-trip confirmed returning 138 resources each):

| Client | Version | Status | Config |
|---|---|---|---|
| Claude Code | 2.1.183 | connected | `~/.claude/settings.json` |
| Codex | 0.134.0 | connected | `~/.codex/config.toml` |
| Hermes | 0.16.0 | connected | `~/.hermes/config.yaml` |
| Agy | 1.0.10 | installed, not yet connected | config location unknown |

Agy is installed but has no discoverable config directory yet. Add `shuk connect agy` when Agy's MCP server registration mechanism is known.

### Manual registration

**Claude Code** (writes to `~/.claude/settings.json`):
```bash
claude mcp add shukhood -- shuk skills serve
```

**Codex** (writes to `~/.codex/config.toml`):
```bash
codex mcp add shukhood -- shuk skills serve
```

**Hermes** — add under `mcp_servers:` in `~/.hermes/config.yaml`, then restart Hermes:
```yaml
mcp_servers:
  shukhood:
    command: shuk
    args: [skills, serve]
    enabled: true
```

Shukhood does not auto-write `~/.hermes/config.yaml`. That file is a live Hermes config; `shuk connect hermes` prints the block above for you to paste.

### Verification

Test the server directly over JSON-RPC stdio:
```bash
python3 -c "
import subprocess, json, threading, time
msgs = [
    json.dumps({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'verify','version':'0'}}}),
    json.dumps({'jsonrpc':'2.0','method':'notifications/initialized','params':{}}),
    json.dumps({'jsonrpc':'2.0','id':2,'method':'resources/list','params':{}}),
]
proc = subprocess.Popen(['shuk','skills','serve'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
results = []
t = threading.Thread(target=lambda: [results.append(l.decode().strip()) for l in proc.stdout if l.strip()], daemon=True)
t.start()
[proc.stdin.write((m+'\n').encode()) or proc.stdin.flush() or time.sleep(0.5) for m in msgs]
time.sleep(2); proc.stdin.close(); proc.wait(timeout=5)
for line in results:
    obj = json.loads(line)
    if obj.get('id') == 2:
        print('resources:', len(obj['result']['resources']))
"
```

---

## Other commands

```bash
shuk setup               # install/link the shuk command
shuk doctor              # check Shukhood and all connected clients
shuk backup              # back up safe configs
shuk update              # pull latest Shukhood repo changes
shuk secrets             # manage secrets (.env)
```

---

## First setup on a new machine

```bash
cd ~/Developer/shukhood
./setup.sh               # installs shuk to ~/.local/bin/
shuk doctor              # confirm tools and skills dir
shuk connect --all       # register with every present MCP client
shuk skills status       # verify skill count
```

---

## Configuration — `.shukhood.yml`

`.shukhood.yml` configures required and optional tool checks run by `shuk doctor`. It does not configure the MCP server — MCP connections are managed entirely via `shuk connect` and written to each client's own config file.

---

## Callable tools

The server exposes `@mcp.tool()` functions alongside skill resources. Agents invoke these directly rather than reading documentation and running scripts manually.

| Tool | What it does |
|---|---|
| `extract_pdf(path, mode, pages)` | Extract text / markdown / tables / metadata from a PDF. `mode`: text (default), markdown, tables, metadata. `pages`: optional range like `"0-4"`. Requires `pymupdf`. |
| `list_simulators(device_type, suggest)` | List available iOS simulators. Returns JSON. **Requires Xcode.app** (not just CLT). |
| `boot_simulator(udid, wait_ready, timeout)` | Boot a simulator by UDID. `wait_ready=True` blocks until responsive. **Requires Xcode.app.** |
| `shutdown_simulator(udid, shutdown_all)` | Shut down one simulator or all booted ones. **Requires Xcode.app.** |
| `launch_app(bundle_id, udid, launch_args)` | Launch an iOS app in the simulator. **Requires Xcode.app.** |
| `terminate_app(bundle_id, udid)` | Terminate a running iOS app. **Requires Xcode.app.** |
| `list_simulator_apps(udid)` | List installed apps in the booted simulator. **Requires Xcode.app.** |

`extract_pdf` is fully functional. The 6 iOS tools are correctly wired but non-functional on this machine: `simctl` ships only with the full Xcode.app (not CLT) and Xcode.app is not installed. Install Xcode from the App Store to enable them.

### Tool promotion candidates (not yet implemented)

- **`medical-research/litbase/lookup_paper.py`** — Semantic Scholar paper lookup by DOI or title. Needs API key handling refactored to env var.
- **`medical-research/reference-search/pubmed_search.py`** — PubMed search. Needs `NCBI_EMAIL` env var instead of hardcoded placeholder.
- **`medical-research/unstructured-medical-text-miner/`** — Clinical text entity extraction. Regex path works today; NLP path requires spaCy + model download.

---

## Migration history

Skills were originally installed by Hermes into `~/.hermes/skills/`. On 2026-06-19, all 102 skill directories were vendored into this repo's `skills/` directory via `shuk skills sync`, with `.shukhood-source.json` provenance files written for each. On 2026-06-20, `skills/` became the canonical home and `~/.hermes/skills/` was archived to `~/.hermes/skills.migrated-to-shukhood/`.

This history explains why provenance files contain `"synced_from": "~/.hermes/skills/..."` entries for skills vendored before the migration — those are historical records, not live dependencies. The `synced_from` field for skills updated after the migration reads `"canonical-repo"`.

---

## Design

- CLI: `shuk`
- Brand: `$HUKHOOD`
- Theme: Nord
- MCP server: FastMCP 3.4.2, stdio transport
- Skills: canonical in `skills/`, gitignored content, provenance-tracked per-dir via `.shukhood-source.json`
- Source-of-truth for skill upstream URLs: `apps/skills/skill-sources.json`
- Python env: `uv`-managed venv at `apps/skills/.venv`

See `docs/architecture.md`, `docs/security.md`, and `docs/command-reference.md`.
