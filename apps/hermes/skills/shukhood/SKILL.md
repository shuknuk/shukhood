---
name: shukhood
description: "Shukhood: the user's personal AI home and wrapper layer for Hermes, Codex, Claude Code, Agy, OpenCode, skills, MCPs, and CLI tooling."
version: 0.1.0
author: Shukhood
license: MIT
metadata:
  hermes:
    tags: [shukhood, ai-home, cli, hermes, mcp]
---

# Shukhood

Shukhood is the user's private AI control plane. It wraps official agent tools while keeping them updateable.

- CLI command: `shuk`
- Brand: `$HUKHOOD`
- Theme: Nord
- First backend: Hermes
- Hermes profile: `shukhood`
- Raw official Hermes stays available as `hermes`
- Shukhood-managed Hermes launches as `shuk hermes`

Prefer supported extension points: profiles, config, skills, MCPs, plugins, and wrapper scripts. Avoid patching official tool internals unless explicitly requested.
