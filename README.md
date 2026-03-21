# 🔒 Snyk Security Statusline for Claude Code

A Claude Code statusline that shows **live vulnerability status** for your project while you code with Claude. Runs `snyk test` in the background and surfaces security issues directly in your Claude Code status bar.

## What it shows

```
🔒 snyk │ ✘ 6 vulns (6 fixable) │ H:4 M:2 │ test-project · 5m ago ⟳
🔒 snyk │ ✔ no issues │ my-app · 2m ago
🔒 snyk │ test-project scanning deps...
🔒 snyk │ no deps to scan
🔒 snyk │ ⚠ auth required  run: snyk auth
```

| Segment | Meaning |
|---|---|
| `✔ no issues` | No vulnerabilities found |
| `✘ N vulns` | N vulnerabilities detected |
| `(N fixable)` | N issues have an available fix (upgrade/patch) |
| `C:N H:N M:N L:N` | Count by severity: Critical / High / Medium / Low |
| `· Xs ago` | How old the last scan result is |
| `⟳` | A background scan is currently running |
| `no deps to scan` | No supported manifest found in this directory |
| `⚠ auth required` | Snyk CLI needs authentication |

**Color coding:**
- 🔴 Red — Critical severity
- 🟠 Orange — High severity
- 🟡 Yellow — Medium severity
- ⬜ Dim — Low severity / metadata
- 🟢 Green — Clean (no issues)

## Why this is useful

When you're coding with Claude, security context lives in a different window, a CI dashboard, or nowhere at all. This statusline brings it into the same place you're working:

- **Severity breakdown (C/H/M/L) at a glance** — know immediately if you have critical issues without leaving the editor
- **Fixable count** — `(6 fixable)` tells you vulns have available upgrades, so action is clear and immediate
- **Scan age** — `· 5m ago` shows how fresh the data is, so you know whether to trust it
- **Auth warning** — surfaces unauthenticated state so you know to run `snyk auth` before wasting time wondering why nothing scans
- **Project name** — confirms you're looking at the right project, especially useful when switching between repos

### Why background caching?

`snyk test` takes 10–30 seconds to run. Blocking Claude Code on every assistant message would make it unusable. Instead:

1. The script **always renders instantly** from the last cached result
2. When the cache is stale (default: 5 minutes), a **background scan fires** without blocking anything
3. The `⟳` spinner tells you a fresher result is on the way

The result: you always have security status visible, updated continuously, with zero impact on Claude's response time.

## What scan type is used — and why

The statusline uses **`snyk test`** (open-source / SCA scanning). This scans your project's dependency manifest files (`package.json`, `requirements.txt`, `go.mod`, etc.) against Snyk's vulnerability database.

### Snyk CLI scan types at a glance

| Command | What it scans | Used by statusline |
|---|---|---|
| `snyk test` | **Open-source dependencies** — finds known CVEs in your packages | ✅ Yes |
| `snyk code test` | **SAST** — static analysis of your own source code for security bugs | Not yet |
| `snyk iac test` | **Infrastructure as Code** — Terraform, Kubernetes, Helm, CloudFormation | Not yet |
| `snyk container test` | **Container images** — OS packages inside Docker images | Not yet |

**Why only `snyk test`?** Dependency scanning is the most universally applicable scan — it works on any project with a manifest file, runs in seconds, and is the highest-signal check for most developers day-to-day. SAST and IaC scans are slower and more context-specific.

You can extend the scan scope using `SNYK_SCAN_ARGS` (e.g. `--all-projects` to scan monorepos) or run the other scan types manually alongside the statusline.

### What data is surfaced from `snyk test`

| Data point | Source field | Shown as |
|---|---|---|
| Total vulnerability count | `uniqueCount` | `✘ N vulns` |
| Severity breakdown | `vulnerabilities[].severity` | `C:N H:N M:N L:N` |
| Fixable count | `isUpgradable \|\| isPatchable` | `(N fixable)` |
| Project name | `projectName` | e.g. `test-project` |
| Package manager | `packageManager` | (used internally) |

## How it works

1. When Claude Code starts, the statusline script is invoked after each assistant message.
2. On first run (or when the cache is stale), it fires `snyk test --json` **in the background** — so your Claude session is never blocked.
3. Results are cached in `~/.cache/snyk-statusline/` and refreshed every 5 minutes by default.
4. You always see the last known result instantly; the `⟳` indicator tells you a fresher scan is underway.

> **Performance note:** `snyk test` can take 10–30 seconds. The background caching means the statusline always renders immediately — it never blocks Claude.

## Prerequisites

- [**Claude Code**](https://claude.ai/code) installed and authenticated
- [**Snyk CLI**](https://docs.snyk.io/snyk-cli/install-or-update-the-snyk-cli) — `npm install -g snyk`
- [**jq**](https://jqlang.github.io/jq/) — `apt install jq` / `brew install jq`
- **Snyk account** (free tier works) — authenticate with `snyk auth`

## Quick start

```bash
# 1. Clone this repo
git clone https://github.com/your-org/snyk-security-statusline
cd snyk-security-statusline

# 2. Authenticate with Snyk (if not already done)
snyk auth

# 3. Run the installer
./install.sh
```

The installer:
- Makes `statusline.sh` executable
- Adds (or updates) the `statusLine` entry in `~/.claude/settings.json`
- Checks for required dependencies

Restart Claude Code for the statusline to appear.

## Manual installation

If you prefer to configure manually, add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/snyk-security-statusline/statusline.sh"
  }
}
```

Make the script executable:

```bash
chmod +x /absolute/path/to/snyk-security-statusline/statusline.sh
```

## Uninstall

```bash
./install.sh --remove
```

## Configuration

All options are controlled via environment variables. Set them in your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) or in `~/.claude/settings.json` under `env`.

| Variable | Default | Description |
|---|---|---|
| `SNYK_STATUSLINE_TTL` | `300` | Seconds between vulnerability scans |
| `SNYK_SHOW_LOW` | `false` | Include low-severity issues in the display |
| `SNYK_SCAN_ARGS` | `""` | Extra arguments passed to `snyk test` |
| `SNYK_BIN` | `snyk` | Path to the Snyk CLI binary |

### Examples

**Scan every 10 minutes instead of 5:**
```bash
export SNYK_STATUSLINE_TTL=600
```

**Show all severity levels including low:**
```bash
export SNYK_SHOW_LOW=true
```

**Scan only production dependencies:**
```bash
export SNYK_SCAN_ARGS="--prod"
```

**Use a specific Snyk org:**
```bash
export SNYK_SCAN_ARGS="--org=my-org-id"
```

**Set via `~/.claude/settings.json`:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "/path/to/snyk-security-statusline/statusline.sh"
  },
  "env": {
    "SNYK_STATUSLINE_TTL": "600",
    "SNYK_SHOW_LOW": "true"
  }
}
```

## Troubleshooting

**Statusline shows "auth required"**
```bash
snyk auth          # opens browser to authenticate
snyk whoami        # verify authentication
```

**Statusline shows "initializing..." forever**
```bash
# Run snyk test manually to check for errors
snyk test

# Check the error log for your project
ls ~/.cache/snyk-statusline/
cat ~/.cache/snyk-statusline/*.err
```

**Snyk not found**
```bash
npm install -g snyk
# or specify the path explicitly:
export SNYK_BIN=/usr/local/bin/snyk
```

**Results are stale**
```bash
# Force a fresh scan by deleting the cache
rm -rf ~/.cache/snyk-statusline/
```

**jq not found**
```bash
# Debian/Ubuntu
sudo apt install jq

# macOS
brew install jq

# Alpine
apk add jq
```

## Cache details

- **Location:** `~/.cache/snyk-statusline/`
- **Files per project:**
  - `{hash}.json` — last scan result (raw `snyk test --json` output)
  - `{hash}.err` — last scan stderr (useful for debugging auth issues)
  - `{hash}.lock/` — atomic lock directory (present only while a scan is running)
  - `{hash}.meta` — scan metadata
- The hash is derived from the absolute path of the project's git root, so each project has its own independent cache.

## How the statusline protocol works

Claude Code invokes the statusline script after each assistant message, piping a JSON object on stdin with session metadata:

```json
{
  "model": "claude-opus-4-6",
  "contextWindowPercent": 12.5,
  "sessionCost": 0.042,
  "gitBranch": "main",
  "worktreeName": null,
  "vimMode": "NORMAL",
  "permissionMode": "default"
}
```

The script reads this via `cat` on stdin, then prints its output to stdout. The output is rendered in Claude Code's status bar and supports ANSI color escape codes.

The script runs in the **same working directory** as your Claude Code session, which is how it knows which project to scan.

See the [Claude Code statusline documentation](https://code.claude.com/docs/en/statusline.md) for the full protocol spec.
