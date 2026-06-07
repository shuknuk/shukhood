# Shukhood Architecture

Shukhood is a wrapper/control layer above official AI agent tools.

Raw tools remain updateable:

- `hermes`
- `codex`
- `claude`
- `agy`
- `opencode`

Shukhood-managed launches:

- `shuk hermes`
- `shuk codex`
- `shuk claude`
- `shuk agy`
- `shuk opencode`

The first implementation supports Hermes. `shuk hermes` launches:

```bash
hermes --profile shukhood --skills shukhood-router
```

This keeps raw `hermes` untouched while making Shukhood the user's personal AI home.
