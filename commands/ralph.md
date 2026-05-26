# Ralph Wiggum Loop Command

Iterative refinement loop that keeps working until complete. The **stop hook** controls iteration via Cursor's `followup_message` API.

## Usage

```
/ralph-loop "<prompt>" [--max-iterations <n>] [--completion-promise "<text>"]
/ralph-loop --continue <trace_id>
```

- **`<prompt>`** (required) — Task description
- **`--max-iterations <n>`** — Safety limit (default: 20)
- **`--completion-promise "<text>"`** — Completion signal (default: "COMPLETE")
- **`--continue <trace_id>`** — Resume from existing state (legacy fallback when keyboard continuation is used)

**If no prompt provided**: Print error with usage and stop.

## On Invocation

### New Loop

1. **Validate arguments** — Error if no prompt
2. **Create state file** at `/tmp/cursor-ralph-loop-${CURSOR_TRACE_ID}.json`:

```json
{
  "prompt": "<user's prompt>",
  "max_iterations": 20,
  "completion_promise": "COMPLETE",
  "iterations": 0,
  "stop": false,
  "last_output": ""
}
```

3. **Start working** on the prompt immediately

### Continuation (`--continue`)

1. **Read existing state file** using provided trace_id
2. **Resume working** on the saved prompt

## During Work

- Make progress on the task
- When you complete a meaningful step, update the state file:

```bash
STATE_FILE="/tmp/cursor-ralph-loop-${CURSOR_TRACE_ID}.json"
jq --arg out "summary of what you did" '.last_output = $out' "$STATE_FILE" > tmp && mv tmp "$STATE_FILE"
```

- When task is **fully complete**, output the completion promise exactly (e.g., `COMPLETE`)

## How the Loop Works

The stop hook (`hooks/ralph-loop-stop.sh`) runs after **every** agent response:

1. Increments iteration counter
2. Checks if completion promise found in `last_output`
3. Checks if max iterations reached
4. Otherwise returns `followup_message` to continue the loop

**Required hook config:** set `"loop_limit": null` on the stop hook entry in `hooks.json` (see `hooks/hooks.json.example`). Without this, Cursor caps automatic follow-ups at 5 iterations on all platforms.

**User clicking Stop** sets `stop: true` in state file — hook detects this and exits.

## Key Rules

1. **Always create state file first** — Hook needs it to function
2. **Update `last_output`** after meaningful work — Hook checks this for completion
3. **Output completion promise when done** — Exact match required
4. **Don't loop yourself** — The hook handles iteration automatically
5. **For `--continue`** — Read state from provided trace_id, not CURSOR_TRACE_ID

## Linux / Windows

Works on Linux and Windows when:

- The stop hook is registered with `"loop_limit": null` (primary fix)
- **`bash`**, **`jq`**, and **`grep`** are on PATH (Git Bash on Windows)
- Hook scripts are executable (`chmod +x hooks/*.sh`)

Optional keyboard fallback scripts (`continue-linux.sh`, `continue-windows.ps1`) exist for legacy installs that cannot set `loop_limit: null`. Prefer the hooks.json fix.
