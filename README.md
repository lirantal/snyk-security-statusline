# ⬡ Snyk Security Statusline for Claude Code

A Claude Code statusline that shows **live security status** for your project while you code with Claude. Runs two background scans — dependency vulnerabilities (SCA) and source code security issues (SAST) — and surfaces results directly in your Claude Code status bar.

## What it shows

Here's the statusline on Claude Code prompt in the terminal:

```
⬡ snyk │ deps  2 C  4 H  2 M ↑6 │ code ✦ │ nodejs-goof · 5m
```

Here's the statusline screenshot:

<img width="1325" height="788" alt="image" src="https://github.com/user-attachments/assets/dc3ee6e7-4cb4-417e-a76d-33f7bcd68c50" />

Reading left to right:

```
⬡ snyk
```
The statusline label — always present. Rendered in Snyk's electric purple.

```
│ deps  4 H  2 M ↑6
```
**SCA segment** (`snyk test`): dependency vulnerabilities found in your packages.
- `deps` — identifies this as the open-source dependency scan
- ` 4 H` — 4 High severity CVEs: count on a dark background, severity letter on a vivid orange background
- ` 2 M` — 2 Medium severity CVEs: count on dark background, letter on vivid amber background
- ` 2 C` / ` 1 L` also appear when Critical (red) or Low (gray) issues exist
- `↑6` — all 6 have a fix available via upgrade or patch

```
│ code  2 H  3 M ↑4
```
**SAST segment** (`snyk code test`): security bugs in your own source code (XSS, SQLi, path traversal, command injection, etc.).
- `code` — identifies this as the static analysis scan
- ` 2 H` — 2 High severity code issues
- ` 3 M` — 3 Medium severity code issues
- `↑4` — 4 of those have an auto-fix available

```
│ test-project · 5m
```
Project name and scan freshness — the age shown is the oldest of the two scan results, so you always know the least-fresh data point.

```
⟳
```
A background scan is currently running; the display will update once it completes. Shown in Snyk purple.

---

**Other states the line can show:**

```
⬡ snyk │ deps ✦ │ code ✦ │ my-app · 2m
```
Both scans came back clean — no issues found. `✦` is shown in emerald green.

```
⬡ snyk │ deps scanning... │ code  2 H  3 M │ my-app · 3m ⟳
```
SCA scan still in progress (first run or cache expired); SAST result is already available.

```
⬡ snyk │ no deps to scan │ no code to scan │ bare-project
```
Snyk found no supported manifest files (no `package.json`, `go.mod`, etc.) and no supported source code in this directory.

```
⬡ snyk │ ⚠ not authenticated  snyk whoami --experimental
```
Snyk CLI is not authenticated — verify with `snyk whoami --experimental` (exit 0 = authenticated, exit 2 = not).

---

**Color coding:**
- 🟣 Snyk purple — label, spinner
- 🔴 Red — Critical severity
- 🟠 Orange — High severity
- 🟡 Yellow — Medium severity
- ⬜ Muted purple-gray — Low severity / metadata / separators
- 🟢 Emerald green — Clean (no issues)

## Why this is useful

When you're coding with Claude, security context lives in a different window, a CI dashboard, or nowhere at all. This statusline brings it into the same place you're working:

- **Severity breakdown (C/H/M/L) at a glance** — know immediately if you have critical issues without leaving the editor
- **Fixable count** — `↑6` tells you vulns have available upgrades, so action is clear and immediate
- **Scan age** — `· 5m` shows how fresh the data is, so you know whether to trust it
- **Auth warning** — surfaces unauthenticated state so you can verify with `snyk whoami --experimental` before wasting time wondering why nothing scans
- **Project name** — confirms you're looking at the right project, especially useful when switching between repos

### Why background caching?

`snyk test` takes 10–30 seconds to run. Blocking Claude Code on every assistant message would make it unusable. Instead:

1. The script **always renders instantly** from the last cached result
2. When the cache is stale (default: 5 minutes), a **background scan fires** without blocking anything
3. The `⟳` spinner tells you a fresher result is on the way

The result: you always have security status visible, updated continuously, with zero impact on Claude's response time.

## What scans run — and why

The statusline runs two independent background scans on every project:

| Command | What it finds | Output format |
|---|---|---|
| `snyk test` | **Open-source dependency CVEs** — known vulnerabilities in your packages (`package.json`, `requirements.txt`, `go.mod`, etc.) | JSON with `vulnerabilities[]` array |
| `snyk code test` | **SAST** — security bugs in your own source code: SQLi, XSS, path traversal, command injection, hardcoded secrets, etc. | SARIF 2.1.0 with `runs[0].results[]` |
| `snyk iac test` | Infrastructure as Code misconfigs — Terraform, K8s, Helm | Not yet |
| `snyk container test` | OS packages inside Docker images | Not yet |

The two active scans complement each other: `snyk test` catches vulnerable third-party code you've pulled in; `snyk code test` catches security mistakes in code you've written.

### What data is surfaced

**From `snyk test` (deps):**

| Data point | Source field | Shown as |
|---|---|---|
| Severity breakdown | `vulnerabilities[].severity` | ` N C  N H  N M  N L` (badge per severity) |
| Fixable count | `isUpgradable \|\| isPatchable` | `↑N` |
| No issues | `ok == true` | `deps ✦` |

**From `snyk code test` (code):**

| Data point | Source field | Shown as |
|---|---|---|
| Severity breakdown | SARIF `level`: `error`=High, `warning`=Medium, `note`=Low | ` N H  N M  N L` (badge per severity) |
| Fixable count | `results[].properties.isAutofixable` | `↑N` |
| No issues | `results` is empty | `code ✦` |

## How it works

1. When Claude Code starts, the statusline script is invoked after each assistant message.
2. On first run (or when the cache is stale), both scans fire **in the background** independently — so your Claude session is never blocked.
3. Results are cached separately in `~/.cache/snyk-statusline/` and refreshed every 5 minutes by default.
4. You always see the last known result instantly; the `⟳` indicator shows when either scan is actively running.

> **Performance note:** `snyk test` and `snyk code test` can each take 10–30 seconds. The two scans run in parallel in the background, so the statusline always renders immediately with no impact on Claude.

## Prerequisites

- [**Claude Code**](https://claude.ai/code) installed and authenticated
- [**Snyk CLI**](https://docs.snyk.io/snyk-cli/install-or-update-the-snyk-cli) — `npm install -g snyk`
- [**jq**](https://jqlang.github.io/jq/) — `apt install jq` / `brew install jq`
- **Snyk account** (free tier works) — authenticate once with `snyk auth`, then verify with `snyk whoami --experimental`

## Quick start

```bash
# 1. Clone this repo
git clone https://github.com/your-org/snyk-security-statusline
cd snyk-security-statusline

# 2. Authenticate with Snyk (if not already done)
snyk auth                        # completes OAuth flow in browser
snyk whoami --experimental       # verify: exit 0 = authenticated

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

To also remove cached scan results:

```bash
rm -rf ~/.cache/snyk-statusline
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

**Statusline shows "not authenticated"**
```bash
snyk whoami --experimental   # exit 0 = authenticated, exit 2 = not
snyk auth                    # run ONLY if not authenticated — re-running when already authed resets credentials
```

**Statusline shows "initializing..." forever**
```bash
# Run snyk test manually to check for errors
snyk test

# Check the error log for your project
ls ~/.cache/snyk-statusline/
cat ~/.cache/snyk-statusline/*.err
```

On macOS, `snyk` may be installed via a Node version manager (nvm, fnm) that adds it to PATH only in interactive shells. Background scans run in a plain subshell and may not inherit that PATH. Fix by pinning the binary path explicitly:
```bash
export SNYK_BIN=$(which snyk)
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
- **Files per project** (keyed by a hash of the git root path):
  - `{hash}.sca.json` — last `snyk test` result
  - `{hash}.sast.json` — last `snyk code test` result (SARIF)
  - `{hash}.sca.err` / `{hash}.sast.err` — stderr from each scan (useful for debugging auth issues)
  - `{hash}.sca.lock/` / `{hash}.sast.lock/` — atomic lock directories (present only while a scan is running)
  - `{hash}.sca.noscan` / `{hash}.sast.noscan` — sentinel written when no supported project was found (exit code 3)
- Each scan type has its own independent cache, so a slow SAST scan never blocks a fresh SCA result from showing.

## How the statusline protocol works

Claude Code invokes the statusline script after each assistant message, piping a JSON object on stdin with session metadata:

```json
{
  "model": { "id": "claude-opus-4-6", "display_name": "Opus" },
  "cwd": "/your/project",
  "workspace": { "current_dir": "/your/project", "project_dir": "/your/project" },
  "context_window": { "used_percentage": 12, "remaining_percentage": 88 },
  "cost": { "total_cost_usd": 0.042, "total_duration_ms": 45000 },
  "vim": { "mode": "NORMAL" },
  "worktree": { "name": "my-feature" }
}
```

The script reads this via `cat` on stdin, then prints its output to stdout. The output is rendered in Claude Code's status bar and supports ANSI RGB color escape codes.

The script runs in the **same working directory** as your Claude Code session, which is how it knows which project to scan.

See the [Claude Code statusline documentation](https://code.claude.com/docs/en/statusline.md) for the full protocol spec.
