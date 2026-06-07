---
name: shukhood-router
description: "Always-loaded Shukhood routing skill. Use inside the shukhood Hermes profile to route tasks to GStack, Hermes, GitHub, MCP, design, research, and devops skills without preloading all full skill docs."
version: 0.1.0
author: Shukhood
license: MIT
metadata:
  hermes:
    tags: [shukhood, routing, skills, gstack, hermes]
---

# Shukhood Router

You are running inside the Shukhood Hermes profile: the user's personal AI home.

## Main rule

Do not preload every large skill. Load full skills only when the user task needs them.

## Routing

- Hermes setup/config/tools/profiles/gateway/MCP -> load `hermes-agent`; for MCP details load `native-mcp`.
- Web app QA, dogfooding, browser bug discovery -> load `gstack-qa`, `gstack-qa-only`, `browse`, or `dogfood` as appropriate.
- Visual/design review -> load `gstack-design-review`, `design-review`, `design-html`, `popular-web-designs`, or `sketch` as appropriate.
- Code/PR review -> load `gstack-review`, `github-code-review`, or `requesting-code-review`.
- PR lifecycle, branch, commit, merge, release -> load `github-pr-workflow` or `github-repo-management`.
- Shipping/deploying -> load `gstack-ship`, `gstack-land-and-deploy`, or `gstack-setup-deploy`.
- Planning/specs -> load `gstack-spec`, `writing-plans`, `plan`, or `gstack-plan-*` review skills.
- Debugging/root cause -> load `systematic-debugging` or `gstack-investigate`.
- GitHub issues/repos/auth -> load `github-issues`, `github-repo-management`, or `github-auth`.
- ASCII/terminal branding -> load `ascii-art`.
- Research -> load `arxiv`, `blogwatcher`, `llm-wiki`, `youtube-content`, or relevant research skills.

## Verification

When building, running, or verifying something, produce a working artifact backed by real tool output. Do not claim success unless verified.

## Security

Never commit raw API keys, OAuth tokens, auth.json files, sessions, logs, browser cookies, or `.env` files. Prefer templates or encrypted secrets.
