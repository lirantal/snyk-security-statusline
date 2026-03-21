# Development Guide

Development happens inside a devcontainer to provide a consistent, isolated environment. The container is based on the official Microsoft Node.js 24 (Debian Bookworm) devcontainer image.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) running locally
- Node.js available on the host (for `npx`)

## Spinning up the environment

From the repo root, run:

```bash
.devcontainer/start.sh
```

This uses `@devcontainers/cli` via `npx` (no global install required) to:

1. Build and start the container according to `.devcontainer/devcontainer.json`
2. Run one-time post-create setup (see below)
3. Drop you into an interactive bash shell inside the container

Your working directory inside the container is `/workspaces/snyk-security-statusline`.

## What the container provides

The post-create script (`.devcontainer/post-create.sh`) runs automatically on first start and installs:

- **Snyk CLI** — `snyk` available at `/usr/local/bin/snyk`
- **Claude Code** — `claude` available for AI-assisted development

## Host files mounted into the container

| Host path | Container path | Purpose |
|---|---|---|
| `~/.gitconfig` | `/home/node/.gitconfig` | Git identity and config |
| `~/.claude` | `/home/node/.claude` | Claude Code auth and settings |

The `~/.claude` mount means Claude Code inside the container uses your existing authentication — no re-login needed.

## Running Claude Code inside the container

Once inside the container shell:

```bash
claude
```

## Notes

- `pnpm install` runs automatically on first start via `postCreateCommand`
- The dev server starts automatically via `postStartCommand` (`pnpm run dev`)
- Git commit signing is disabled inside the container (`commit.gpgsign false`) since GPG keys are not mounted
