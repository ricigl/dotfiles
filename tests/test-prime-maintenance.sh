#!/usr/bin/env bash
# Focused disposable tests for the Prime maintenance utility.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/prime-maintenance-test.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

session_dir="$tmp_dir/sessions"
outside="$tmp_dir/outside.jsonl"
mkdir -p "$session_dir/nested"

python3 - "$session_dir" "$outside" <<'PY'
import json
import pathlib
import sys

session_dir = pathlib.Path(sys.argv[1])
outside = pathlib.Path(sys.argv[2])

def write_session(path, session_id, state, name, secret):
    entries = [
        {
            "type": "session",
            "version": 3,
            "id": session_id,
            "timestamp": "2026-08-23T10:00:00.000Z",
            "cwd": "/home/ricardo/src/example",
        },
        {
            "type": "message",
            "id": "message-1",
            "parentId": None,
            "timestamp": "2026-08-23T10:00:01.000Z",
            "message": {"role": "user", "content": secret},
        },
        {
            "type": "session_info",
            "id": "info-1",
            "parentId": "message-1",
            "timestamp": "2026-08-23T10:00:02.000Z",
            "name": name,
        },
        {
            "type": "session_state",
            "id": "state-1",
            "parentId": "info-1",
            "timestamp": "2026-08-23T10:00:03.000Z",
            "state": state,
        },
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(entry) for entry in entries) + "\n", encoding="utf-8")

write_session(session_dir / "session-one.jsonl", "session-one", "archived", "Review session", "PRIVATE_PROMPT_SHOULD_NOT_PRINT")
write_session(session_dir / "nested" / "active-session.jsonl", "active-session", "active", "Active session", "ACTIVE_PRIVATE_PROMPT")
write_session(outside, "outside-session", "archived", "Outside session", "OUTSIDE_PRIVATE_PROMPT")
PY

listing="$($ROOT/scripts/prime-maintenance.py list-sessions --session-dir "$session_dir")"
printf '%s\n' "$listing" | grep -q 'session-one'
printf '%s\n' "$listing" | grep -q 'active-session'
printf '%s\n' "$listing" | grep -q 'state=archived'
printf '%s\n' "$listing" | grep -q 'state=active'
if printf '%s\n' "$listing" | grep -q 'PRIVATE_PROMPT'; then
  printf '%s\n' 'Session listing leaked message content.' >&2
  exit 1
fi

if printf '\n' | "$ROOT/scripts/prime-maintenance.py" delete-session session-one --session-dir "$session_dir" >/dev/null 2>&1; then
  printf '%s\n' 'Deletion unexpectedly succeeded without confirmation.' >&2
  exit 1
fi
test -f "$session_dir/session-one.jsonl"

if "$ROOT/scripts/prime-maintenance.py" delete-session "$outside" --session-dir "$session_dir" --yes --permanent >/dev/null 2>&1; then
  printf '%s\n' 'Outside session path was accepted.' >&2
  exit 1
fi
test -f "$outside"

if "$ROOT/scripts/prime-maintenance.py" delete-session active-session --session-dir "$session_dir" --yes --permanent >/dev/null 2>&1; then
  printf '%s\n' 'Active session was deleted.' >&2
  exit 1
fi
test -f "$session_dir/nested/active-session.jsonl"

"$ROOT/scripts/prime-maintenance.py" delete-session session-one --session-dir "$session_dir" --yes --permanent >/dev/null
test ! -e "$session_dir/session-one.jsonl"

"$ROOT/scripts/prime-maintenance.py" --help >/dev/null
printf '%s\n' 'prime-maintenance disposable tests passed.'
