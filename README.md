# $HUKHOOD

Shukhood is a shared skills MCP server. It vendors your Hermes skill library into a local `skills/` directory with provenance tracking, then exposes all of it over the Model Context Protocol so any MCP-capable agent — Claude Code, Codex, Hermes, or others — can read from a single source of truth.

The Hermes launcher (`shuk hermes`) is still here and still works. It is no longer the point.

---

## Quick start

```bash
# First run: vendor skills and connect clients
shuk skills sync          # copy ~/.hermes/skills/ → skills/ with provenance
shuk connect --all        # register with every present MCP client
shuk skills serve         # start the server (clients launch this automatically)
```

---

## Skills MCP server

### Commands

```bash
shuk skills serve                # start the MCP server over stdio
shuk skills sync                 # vendor ~/.hermes/skills/ into skills/ with provenance
shuk skills status               # show server config, venv path, and skill counts
shuk skills check                # report sync status for all source-tracked skills
shuk skills check --no-fetch     # same, skip git fetch (no network)
shuk skills update <name>        # re-vendor one source-tracked skill (conflict-safe)
shuk skills update --all         # re-vendor all source-tracked skills
```

### How it works

**Vendoring.** `shuk skills sync` copies each skill directory from `~/.hermes/skills/` into `skills/` inside this repo. Each copied directory gets a `.shukhood-source.json` provenance file recording the source group name, remote URL, git commit, and a content hash. The `skills/` tree is gitignored — it is a local cache, not tracked state.

**Skills directory resolution.** The MCP server reads from `skills/` if it is populated. If not, it falls back to `~/.hermes/skills/` directly. Override either with `SHUKHOOD_SKILLS_DIR=<path>`.

**Category collapse.** Skills are organized as flat dirs (`skill://superpowers`) or nested dirs (`skill://medical-research/<subskill>`). Any category containing more than 10 sub-skills is collapsed: `list_resources()` exposes one `skill://<category>` index resource listing all sub-skill names and one-line descriptions. Individual sub-skills are readable via template URI `skill://<category>/<subname>` but do not appear in the flat list. Categories at or under 10 sub-skills list individually. The threshold is `CATEGORY_THRESHOLD = 10` in `apps/skills/server.py`.

**Resource count.** With 102 vendored skill dirs containing ~925 individual sub-skills, `list_resources()` returns 138 resources. Every sub-skill is still readable on demand via its URI.

**Provenance model.** Skills fall into two tiers:
- **Source-tracked** — 25 source groups (17 top-level dirs) with a known git remote in `~/.hermes/manual-skill-sources.json`. These participate in `shuk skills check` and `shuk skills update`.
- **Local-only** — everything else (~70+ dirs: `gstack-*`, `dogfood`, `voicebox`, etc.). Vendored as-is. No upstream sync attempted. Shukhood is the source of truth for these copies.

**Conflict handling.** `shuk skills update` uses a four-state decision matrix before writing anything: if your vendored copy has local edits AND Hermes has pulled new upstream content since your last sync, it stops with a conflict error and touches nothing. Manual resolution required. Conflict default is always detect-and-warn, never auto-overwrite.

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

`shuk connect` is idempotent — re-running it on an already-registered client is a no-op.

### Manual registration

**Claude Code** (writes to `~/.claude/settings.json` or per-project `.claude.json`):
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

**Verification.** After any registration, the server can be tested directly over stdio:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n{"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}}\n' \
  | (shuk skills serve 2>/dev/null & sleep 5; kill $! 2>/dev/null)
```

---

## Hermes launcher (secondary)

```bash
shuk hermes              # launch Hermes with the shukhood profile
shuk hermes raw          # launch raw official Hermes
shuk hermes setup        # create/apply the shukhood Hermes profile
shuk hermes backup       # back up Hermes profile/config files
shuk hermes doctor       # check Hermes, profile, skills, and MCP readiness
shuk hermes update       # run official Hermes update
```

The launcher injects the `shukhood` profile and preloads the `shukhood-router` skill. It does not change Hermes itself — raw `hermes` still works unchanged.

---

## Other commands

```bash
shuk setup               # install/link the shuk command
shuk doctor              # check Shukhood and all supported tools
shuk backup              # back up safe configs for supported tools
shuk update              # pull latest Shukhood repo changes
```

---

## First setup

```bash
cd ~/Developer/shukhood
./setup.sh
shuk doctor
shuk skills sync
shuk connect --all
shuk skills status
```

For the Hermes launcher specifically:
```bash
shuk hermes setup --dry-run
shuk hermes setup
shuk hermes
```

---

## Configuration — `.shukhood.yml`

`.shukhood.yml` configures the **launcher** (profile injection, backup policy, required tools). It does not configure the MCP server — MCP connections are managed via `shuk connect` and are written to each client's own config file.

The `codex: enabled: false` and `claude: enabled: false` fields in `.shukhood.yml` are launcher-scoped (they would suppress `shuk codex` / `shuk claude` launcher stubs if those existed). They do not affect whether those clients connect to the MCP server — that is controlled entirely by `shuk connect`.

---

## Callable tools (Phase 2 — implemented)

The server exposes `@mcp.tool()` functions alongside the skill resources. Agents can invoke these directly rather than reading documentation and running scripts manually.

| Tool | What it does |
|---|---|
| `extract_pdf(path, mode, pages)` | Extract text / markdown / tables / metadata from a PDF. `mode`: text (default), markdown, tables, metadata. `pages`: optional range like `"0-4"`. Requires `pymupdf`. |
| `list_simulators(device_type, suggest)` | List available iOS simulators. Returns JSON with counts and booted device. **Requires Xcode.app** (not just CLT). |
| `boot_simulator(udid, wait_ready, timeout)` | Boot a simulator by UDID. `wait_ready=True` blocks until the device is responsive. **Requires Xcode.app.** |
| `shutdown_simulator(udid, shutdown_all)` | Shut down one simulator or all booted ones. **Requires Xcode.app.** |
| `launch_app(bundle_id, udid, launch_args)` | Launch an iOS app in the simulator. **Requires Xcode.app.** |
| `terminate_app(bundle_id, udid)` | Terminate a running iOS app. **Requires Xcode.app.** |
| `list_simulator_apps(udid)` | List installed apps in the booted simulator. **Requires Xcode.app.** |

`extract_pdf` is fully functional. The 6 iOS tools are correctly implemented and pass the MCP plumbing round-trip, but are **non-functional on this machine**: `xcrun` and Command Line Tools are installed, but `simctl` ships only with the full Xcode.app (not CLT) and Xcode.app is not installed. Install Xcode from the App Store to enable them.

## Remaining tool promotion candidates (not yet implemented)

These scripts were reviewed in Phase 2 and are available to promote if needed:

- **`medical-research/litbase/lookup_paper.py`** — Semantic Scholar paper lookup by DOI or title. Needs `config.json` API key handling refactored to env var.
- **`medical-research/reference-search/pubmed_search.py`** — PubMed search from title + abstract text. Needs `NCBI_EMAIL` env var instead of hardcoded placeholder.
- **`medical-research/unstructured-medical-text-miner/`** — Clinical text entity extraction. Regex path works today; full NLP path requires spaCy + model download.

Scripts reviewed and ruled out for promotion: `litbase/recommend.py` (workflow step), `litbase/rename_pdfs.py` (destructive + hardcoded paths), `experiment-detail-comparator/run_comparison.py` (6-step pipeline), `torchdrug-english/translate_md.py` (hardcoded Windows paths), `ppt/build_html.py` (project-specific), `paper-tweet-generator/extract_pdf.py` (redundant).

## What's not done yet

**`shuk connect --verify`.** Re-run the JSON-RPC health check against an already-registered connection without re-registering. Useful after a venv rebuild or `shuk skills sync` to confirm the server is still responding. Currently `shuk connect --list` only checks config-file registration state, not live server health.

---

## Design

- CLI: `shuk`
- Brand: `$HUKHOOD`
- Theme: Nord
- MCP server: FastMCP 3.4.2, stdio transport
- Skills: vendored from `~/.hermes/skills/`, gitignored, provenance-tracked per-dir
- Python env: `uv`-managed venv at `apps/skills/.venv`, isolated from repo root
- Hermes profile: `shukhood` (launcher use case only)
- Raw official tools remain untouched and updateable

See `docs/architecture.md`, `docs/security.md`, and `docs/command-reference.md`.
