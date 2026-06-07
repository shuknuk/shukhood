# Security Policy

Do not commit raw secrets.

Never commit:

- `.env`
- `auth.json`
- OAuth tokens
- API keys
- session history
- logs
- browser cookies
- provider auth files

Commit only templates such as `secrets/.env.example` or encrypted secrets if intentionally configured later.
