# Claude Code Statusline Protocol

## How it works

Claude Code invokes the statusline script after every assistant message. The script:
1. Receives a JSON object on **stdin** with session metadata
2. Runs any computation it needs
3. Prints one line of text to **stdout**
4. Exits

The output is rendered in Claude Code's status bar. The script runs in the **same
working directory** as the Claude session — this is how it knows which project to scan.

## Session JSON (stdin)

Fields passed to the script on stdin:

| Field | Type | Description |
|---|---|---|
| `model` | string | Model name, e.g. `claude-opus-4-6` |
| `contextWindowPercent` | number | Fraction of context window used (0–100) |
| `sessionCost` | number | Cumulative session cost in USD |
| `gitBranch` | string \| null | Current git branch (worktree sessions only) |
| `worktreeName` | string \| null | Worktree name if in a worktree |
| `vimMode` | string \| null | Vim mode if vim bindings are active |
| `permissionMode` | string | Permission mode: `default`, `auto`, `manual` |
| `agentName` | string \| null | Agent name if running inside a named agent |

Read these with `jq`: `MODEL=$(printf '%s' "$SESSION" | jq -r '.model // empty')`

## Output format

The script prints to stdout. Output supports:
- **ANSI escape codes** — including RGB (`\033[38;2;R;G;Bm` for foreground)
- **Unicode** — emoji, box-drawing characters, symbols
- **OSC 8 hyperlinks** — clickable links (rarely needed)
- **Single line** — multi-line output is supported but one line is standard

Updates are debounced at 300ms. If a new update triggers while the script is running,
the in-flight execution is cancelled. Keep scripts fast — always render from cache.

## settings.json format

The statusline is registered in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/statusline.sh"
  }
}
```

**The value must be an object.** A plain string path causes a startup error:
```
Settings Error: statusLine: Expected object, but received string
```

To update non-destructively with `jq`:
```bash
jq --arg p "/absolute/path/to/statusline.sh" \
   '.statusLine = {"type": "command", "command": $p}' \
   ~/.claude/settings.json > ~/.claude/settings.json.tmp \
   && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

## Script requirements

- Must be executable (`chmod +x`)
- Must read stdin (even if ignoring it): `SESSION=$(cat)`
- Must exit 0 — non-zero exit suppresses the output
- Should complete in under 100ms — run slow work in background, render from cache
