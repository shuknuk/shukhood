# Command Reference

```bash
shuk                     # help/banner

# Core
shuk setup               # link shuk into ~/.local/bin
shuk doctor              # check tools, skills dir, and MCP client connections
shuk backup              # backup safe configs
shuk update              # git pull --ff-only on this repo

# Secrets
shuk secrets check       # check secret presence without printing values
shuk secrets init        # create ~/.hermes/.env from template if missing

# Skills MCP server
shuk skills serve        # start the MCP server over stdio (clients do this automatically)
shuk skills status       # show server config, venv, and skill counts
shuk skills check        # report status for all source-tracked skills (offline, uses sources/)
shuk skills check --fetch      # same, also git fetch upstream remotes
shuk skills update <name>      # update one source-tracked skill from upstream git
shuk skills update --all       # update all source-tracked skills from upstream git

# MCP client registration
shuk connect --list      # show registered / not-registered per client
shuk connect --all       # register with every present client
shuk connect claude      # Claude Code only
shuk connect codex       # Codex only
shuk connect hermes      # print YAML block to paste into ~/.hermes/config.yaml
```

## Removed commands (Phase 6 — 2026-06-20)

The following commands were removed when Shukhood stopped being an agent launcher:

```bash
# REMOVED — no longer available
shuk hermes              # launched Hermes with shukhood profile
shuk hermes raw          # launched raw official Hermes
shuk hermes setup        # created/applied the shukhood Hermes profile
shuk hermes backup       # backed up Hermes profile/config files
shuk hermes doctor       # checked Hermes profile and skills readiness
shuk hermes update       # ran official Hermes update
shuk skills sync         # vendored ~/.hermes/skills/ into skills/ (retired to sync.sh.retired)
```

Use `hermes` directly to launch Hermes. Connect it to Shukhood's MCP server once via `shuk connect hermes`.
