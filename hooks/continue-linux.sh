#!/usr/bin/env bash
# Fallback continuation for Linux when stop-hook followup_message hits Cursor's
# default loop_limit (5). Prefer setting "loop_limit": null in hooks.json instead.
#
# Usage: continue-linux.sh "/ralph-loop --continue <trace_id>"
#
# Requires one of: xdotool (X11), ydotool (Wayland/uinput), or wtype (Wayland).

set -euo pipefail

COMMAND_TEXT="${1:-}"
if [[ -z "$COMMAND_TEXT" ]]; then
  echo "continue-linux.sh: missing command text" >&2
  exit 1
fi

sleep 1.5

type_text() {
  local text="$1"
  if command -v xdotool >/dev/null 2>&1; then
    xdotool type --delay 12 -- "$text"
    xdotool key Return
    return 0
  fi
  if command -v ydotool >/dev/null 2>&1; then
    ydotool type --delay 12 -- "$text"
    ydotool key enter
    return 0
  fi
  if command -v wtype >/dev/null 2>&1; then
    wtype -d 12 -- "$text"
    wtype -k enter
    return 0
  fi
  return 1
}

focus_cursor() {
  if command -v xdotool >/dev/null 2>&1; then
    xdotool search --onlyvisible --class cursor windowactivate 2>/dev/null \
      || xdotool search --onlyvisible --class Cursor windowactivate 2>/dev/null \
      || true
  fi
}

focus_cursor
sleep 0.3

if ! type_text "$COMMAND_TEXT"; then
  echo "continue-linux.sh: install xdotool (X11), ydotool, or wtype (Wayland), or set loop_limit: null in hooks.json" >&2
  exit 1
fi
