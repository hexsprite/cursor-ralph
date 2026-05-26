# cursor-ralph

Agentic looping for Cursor IDE. Keeps the agent working on a task until it's done (or hits a safety limit).

This is a quick port of the "Not-quite-Ralph" loop from the [ralph-wiggum plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) for Claude Code.

## What's a Ralph Loop?

The [Ralph Wiggum technique](https://ghuntley.com/ralph/) is an agentic pattern where you let the AI keep working in a loop until it declares the task complete. Instead of back-and-forth prompting, you give it a goal and let it run.

This implementation isn't the "true" Ralph loop (which uses more sophisticated state management) — it's a pragmatic version that works within Cursor's constraints.

## Installation

1. Clone this repo somewhere:
   ```bash
   git clone https://github.com/hexsprite/cursor-ralph.git ~/.cursor-ralph
   ```

2. Symlink the command into your Cursor commands directory:
   ```bash
   mkdir -p ~/.cursor/commands
   ln -s ~/.cursor-ralph/commands/ralph.md ~/.cursor/commands/ralph.md
   ```

3. Register the stop hook in **`.cursor/hooks.json`** (project root) or your user hooks config. **You must set `loop_limit`: null** so Cursor does not stop the loop after 5 iterations:

   ```json
   {
     "version": 1,
     "hooks": {
       "stop": [
         {
           "command": "~/.cursor-ralph/hooks/ralph-loop-stop.sh",
           "loop_limit": null
         }
       ]
     }
   }
   ```

   See [`hooks/hooks.json.example`](hooks/hooks.json.example) for a copy-paste template.

4. Make hook scripts executable:
   ```bash
   chmod +x ~/.cursor-ralph/hooks/ralph-loop-stop.sh
   ```

### Linux notes

- Works on Linux with **`loop_limit`: null** — no macOS `osascript` required.
- Requires **`bash`**, **`jq`**, and **`grep`** on PATH.
- Optional legacy fallback: [`hooks/continue-linux.sh`](hooks/continue-linux.sh) simulates typing `/ralph-loop --continue <trace_id>` if you cannot set `loop_limit: null`. Install **`xdotool`** (X11) or **`ydotool`** / **`wtype`** (Wayland).


### Windows notes

- Works on Windows with **`loop_limit`: null** — no macOS `osascript` required.
- Hook scripts are **bash**; use **Git Bash** (bundled with Git for Windows) or ensure bash is on PATH when Cursor runs hooks.
- Use forward slashes or escaped backslashes in `hooks.json` command paths, e.g. `"C:/Users/you/.cursor-ralph/hooks/ralph-loop-stop.sh"`.
- Requires **`jq`** in Git Bash (`winget install jqlang.jq` or download from [jqlang.org](https://jqlang.org/)).
- Optional legacy fallback: [`hooks/continue-windows.ps1`](hooks/continue-windows.ps1) uses PowerShell `SendKeys` when `loop_limit: null` cannot be set. Run via Git Bash: `powershell.exe -File hooks/continue-windows.ps1 "/ralph-loop --continue <trace_id>"`.
- Known Cursor quirk: stop-hook JSON may show as `{}` in Hooks Execution Log on Windows even when valid ([forum thread](https://forum.cursor.com/t/stop-hook-followup-message-not-captured-on-windows-execution-log-shows-despite-valid-json-on-stdout/)); verify behavior in chat, not only the log.

### macOS notes

- Grant Accessibility permissions to Cursor if you use the optional keyboard fallback (System Settings → Privacy & Security → Accessibility).
- With `loop_limit: null`, keyboard simulation is not needed.

## Usage

```
/ralph-loop "your task description"
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--max-iterations <n>` | 20 | Safety limit to prevent runaway loops |
| `--completion-promise "<text>"` | `COMPLETE` | The exact string the agent outputs when done |

### Examples

```bash
# Run tests until coverage hits 80%
/ralph-loop "Add tests until we hit 80% coverage" --max-iterations 30

# Fix all TypeScript errors
/ralph-loop "Fix all type errors in src/" --max-iterations 15

# Custom completion signal
/ralph-loop "Refactor auth module" --completion-promise "REFACTOR_DONE"
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                     User: /ralph-loop "task"                │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent works on task, updates state file with progress      │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Stop hook runs after agent response                        │
│  ├─ Check for completion promise → Done? Clean up & exit    │
│  ├─ Check max iterations → Hit limit? Clean up & exit       │
│  └─ Return followup_message to continue (loop_limit: null)  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
                    (loop continues)
```

Cursor limits `followup_message` chains to **5 iterations by default**. Setting **`loop_limit`: null** on the stop hook removes that cap ([Cursor hooks docs](https://cursor.com/docs/hooks.md)). The previous macOS-only `osascript` workaround is no longer required when this is configured.

## State File

Loop state is stored in `/tmp/cursor-ralph-loop-<trace_id>.json`:

```json
{
  "prompt": "the original task",
  "max_iterations": 20,
  "completion_promise": "COMPLETE",
  "iterations": 7,
  "stop": false,
  "last_output": "Added 3 test files, coverage now at 74%"
}
```

## Requirements

- **Cursor** with project or user **`hooks.json`**
- **`loop_limit`: null** on the Ralph stop hook entry
- **`bash`**, **`jq`**, **`grep`**
- On Windows: **Git Bash** (or another environment where bash hooks run)

## Limitations

- Without `loop_limit: null`, the loop still stops after 5 iterations on every OS.
- Keyboard fallback scripts require the Cursor window to be focused and OS-specific tooling (optional; not needed with `loop_limit: null`).

## Credits

- Original Ralph Wiggum technique by [Geoffrey Huntley](https://ghuntley.com/ralph/)
- Based on the [ralph-wiggum plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) for Claude Code
- Cross-platform hook fix inspired by [ericzakariasson/ralph-loop-plugin](https://github.com/ericzakariasson/ralph-loop-plugin)
- This port by Jordan Baker

## License

MIT
