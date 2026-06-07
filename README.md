# $HUKHOOD

Your personal AI home: a Nord-themed CLI wrapper that launches official AI agents with your configs, profiles, skills, MCPs, and routing rules.

Shukhood is not a fork of Hermes, Codex, Claude Code, Agy, or OpenCode. It is the personal control plane above them.

## Daily use

```bash
shuk hermes
```

This launches official Hermes through the `shukhood` Hermes profile and preloads only the tiny `shukhood-router` skill. Full GStack and other skills remain available and are loaded only when relevant.

Raw official Hermes remains available:

```bash
hermes
```

## First setup

```bash
cd ~/Developer/shukhood
./setup.sh
shuk doctor
shuk hermes setup --dry-run
shuk hermes setup
shuk hermes
```

## Design

- CLI: `shuk`
- Brand: `$HUKHOOD`
- Theme: Nord
- First backend: Hermes
- Hermes profile: `shukhood`
- Default Hermes launch: `hermes --profile shukhood --skills shukhood-router`
- Raw official tools remain untouched and updateable
- Secrets are never committed raw

See `docs/architecture.md`, `docs/security.md`, and `docs/command-reference.md`.
