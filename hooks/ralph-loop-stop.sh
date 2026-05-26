#!/usr/bin/env bash
# Ralph loop controller - runs after every agent response.
# When the loop is active, increment counters, check completion, and either stop
# or return followup_message for the next iteration.
#
# Cursor stop hook API (stdin JSON):
#   { "status": "completed"|"aborted"|"error", "loop_count": N, ... }
#   stdout: { "followup_message": "<text>" } to continue, or agent_message / empty to stop
#
# REQUIRED: Register this hook with "loop_limit": null in hooks.json so Cursor
# does not cap followup_message chains at 5 iterations. See hooks/hooks.json.example.

set -euo pipefail

HOOK_INPUT=$(cat)

TRACE_ID="${CURSOR_TRACE_ID:-}"

if [[ -z "$TRACE_ID" ]]; then
  exit 0
fi

STATE_FILE="/tmp/cursor-ralph-loop-${TRACE_ID}.json"

if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

STATE=$(cat "$STATE_FILE")
ITERATIONS=$(echo "$STATE" | jq -r '.iterations // 0')
MAX_ITERATIONS=$(echo "$STATE" | jq -r '.max_iterations // 20')
COMPLETION_PROMISE=$(echo "$STATE" | jq -r '.completion_promise // "COMPLETE"')
PROMPT=$(echo "$STATE" | jq -r '.prompt // ""')
STOP=$(echo "$STATE" | jq -r '.stop // false')
LAST_OUTPUT=$(echo "$STATE" | jq -r '.last_output // ""')

if [[ "$STOP" = "true" ]]; then
  rm -f "$STATE_FILE"
  exit 0
fi

NEW_ITERATIONS=$((ITERATIONS + 1))
jq --argjson iter "$NEW_ITERATIONS" '.iterations = $iter' "$STATE_FILE" > "${STATE_FILE}.tmp" \
  && mv "${STATE_FILE}.tmp" "$STATE_FILE"

if [[ "$NEW_ITERATIONS" -ge "$MAX_ITERATIONS" ]]; then
  rm -f "$STATE_FILE"
  jq -n --arg msg "Max iterations ($MAX_ITERATIONS) reached. Stopping ralph loop." \
    '{agent_message: $msg}'
  exit 0
fi

if [[ -n "$LAST_OUTPUT" ]] && echo "$LAST_OUTPUT" | grep -qF "$COMPLETION_PROMISE"; then
  rm -f "$STATE_FILE"
  jq -n --arg msg "Task completed after $NEW_ITERATIONS iterations." '{agent_message: $msg}'
  exit 0
fi

jq -n \
  --arg prompt "$PROMPT" \
  --arg iter "$NEW_ITERATIONS" \
  --arg max "$MAX_ITERATIONS" \
  --arg promise "$COMPLETION_PROMISE" \
  --arg state_file "$STATE_FILE" \
  '{followup_message: "Continue working on: \($prompt)\n\nIteration \($iter) of \($max).\n\nWhen complete, output exactly: \($promise)\n\nTo record your progress, update the state file:\njq --arg out '\''YOUR_OUTPUT_SUMMARY'\'' '\''.last_output = $out'\'' \"\($state_file)\" > tmp && mv tmp \"\($state_file)\""}'
