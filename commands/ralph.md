# Ralph Wiggum Loop Command

Iterative refinement loop that keeps working until complete. The **stop hook** controls iteration and uses `osascript` to bypass Cursor's 5-iteration limit.

## Usage

```
/ralph-loop "<prompt>" [--max-iterations <n>] [--completion-promise "<text>"]
/ralph-loop --continue <trace_id>
```

- **`<prompt>`** (required) — Task description
- **`--max-iterations <n>`** — Safety limit (default: 20)
- **`--completion-promise "<text>"`** — Completion signal (default: "COMPLETE")
- **`--continue <trace_id>`** — Resume from existing state (used by osascript auto-continuation)

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
  "session_iterations": 0,
  "stop": false,
  "last_output": ""
}
```

3. **Start working** on the prompt immediately

### Continuation (`--continue`)

1. **Read existing state file** using provided trace_id
2. **Resume working** on the saved prompt
3. Session iteration counter is already reset by the stop hook

## During Work

- Make progress on the task
- When you complete a meaningful step, update the state file:

```bash
STATE_FILE="/tmp/cursor-ralph-loop-${CURSOR_TRACE_ID}.json"
jq --arg out "summary of what you did" '.last_output = $out' "$STATE_FILE" > tmp && mv tmp "$STATE_FILE"
```

- When task is **fully complete**, output the completion promise exactly (e.g., `COMPLETE`)

## How the Loop Works

The stop hook (`scripts/ralph-loop-stop.sh`) runs after **every** agent response:

1. Increments iteration counter and session counter
2. Checks if completion promise found in `last_output`
3. Checks if max iterations reached
4. If session hits 5 (Cursor's limit) but total < max:
   - Resets session counter
   - Spawns `osascript` to type `/ralph-loop --continue <trace_id>`
   - New "user message" resets Cursor's internal limit
5. If not at session limit → returns `followup_message` to continue
6. If done → cleans up state file and exits

**User clicking Stop** sets `stop: true` in state file — hook detects this and exits.

## Example

```
User: /ralph-loop "Add tests until 80% coverage" --max-iterations 15

Iterations 1-4: Normal followup_message continuation
Iteration 5: Session limit hit
  → osascript types: /ralph-loop --continue abc123
  → New session starts

Iterations 6-9: Normal continuation
Iteration 10: Session limit hit again
  → osascript continues...

Iteration 12: Coverage reaches 82%
  → Agent outputs: COMPLETE
  → Hook cleans up, loop ends
```

## Key Rules

1. **Always create state file first** — Hook needs it to function
2. **Update `last_output`** after meaningful work — Hook checks this for completion
3. **Output completion promise when done** — Exact match required
4. **Don't loop yourself** — The hook handles iteration automatically
5. **For `--continue`** — Read state from provided trace_id, not CURSOR_TRACE_ID

## macOS Requirement

The osascript auto-continuation requires:
- macOS (osascript is Mac-only)
- Accessibility permissions for System Events
- Cursor window must be focused when session limit hits

If osascript fails, the loop stops at iteration 5 and you can manually continue.
