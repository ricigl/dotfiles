#!/usr/bin/env bash
# Focused deterministic tests for Pi OpenAI server-side compaction session proof validation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/compaction-proof-test.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

valid_session="$tmp_dir/valid-session.jsonl"
wrong_impl_session="$tmp_dir/wrong-impl-session.jsonl"
empty_history_session="$tmp_dir/empty-history-session.jsonl"
no_compaction_item_session="$tmp_dir/no-compaction-item-session.jsonl"
malformed_session="$tmp_dir/malformed-session.jsonl"
nonexistent_session="$tmp_dir/nonexistent.jsonl"

python3 - "$tmp_dir" <<'PY'
import json
import pathlib
import sys

dir_path = pathlib.Path(sys.argv[1])

SECRET_TEXT = "SECRET_PROMPT_DO_NOT_LEAK_IN_LOGS"

# 1. Valid session with responses_compaction_v2 and replacementHistory and final compaction item
valid_entries = [
    {"type": "session", "id": "s-1", "timestamp": 1700000000},
    {"type": "message", "id": "m-1", "message": {"role": "user", "content": SECRET_TEXT}},
    {"type": "message", "id": "m-2", "message": {"role": "assistant", "content": [{"type": "text", "text": "Response"}]}},
    {
        "type": "compaction",
        "id": "c-1",
        "timestamp": 1700000010,
        "details": {
            "remoteCompaction": {
                "implementation": "responses_compaction_v2",
                "replacementHistory": [
                    {"replacedCount": 2, "summary": "Initial context"}
                ],
            }
        },
    },
]
(dir_path / "valid-session.jsonl").write_text(
    "\n".join(json.dumps(e) for e in valid_entries) + "\n", encoding="utf-8"
)

# 2. Wrong implementation
wrong_impl_entries = [
    {"type": "session", "id": "s-2", "timestamp": 1700000000},
    {
        "type": "compaction",
        "id": "c-2",
        "details": {
            "remoteCompaction": {
                "implementation": "responses_compaction_v1",
                "replacementHistory": [{"summary": "Initial context"}],
            }
        },
    },
]
(dir_path / "wrong-impl-session.jsonl").write_text(
    "\n".join(json.dumps(e) for e in wrong_impl_entries) + "\n", encoding="utf-8"
)

# 3. Empty replacementHistory
empty_history_entries = [
    {"type": "session", "id": "s-3", "timestamp": 1700000000},
    {
        "type": "compaction",
        "id": "c-3",
        "details": {
            "remoteCompaction": {
                "implementation": "responses_compaction_v2",
                "replacementHistory": [],
            }
        },
    },
]
(dir_path / "empty-history-session.jsonl").write_text(
    "\n".join(json.dumps(e) for e in empty_history_entries) + "\n", encoding="utf-8"
)

# 4. Missing compaction item
no_compaction_entries = [
    {"type": "session", "id": "s-4", "timestamp": 1700000000},
    {
        "type": "message",
        "id": "m-4",
        "details": {
            "remoteCompaction": {
                "implementation": "responses_compaction_v2",
                "replacementHistory": [{"summary": "Initial context"}],
            }
        },
    },
]
(dir_path / "no-compaction-item-session.jsonl").write_text(
    "\n".join(json.dumps(e) for e in no_compaction_entries) + "\n", encoding="utf-8"
)

# 5. Malformed JSONL
(dir_path / "malformed-session.jsonl").write_text(
    '{"type": "session"}\n{malformed json}\n', encoding="utf-8"
)
PY

validate_fn() {
  local session_file=$1
  python3 - "$session_file" <<'PY'
import json
import pathlib
import sys

def validate_compaction_session(path_str):
    path = pathlib.Path(path_str)
    if not path.is_file():
        return False, f"File not found or not a regular file: {path_str}"

    entries = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line_no, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError as e:
                    return False, f"Malformed JSON on line {line_no}"
    except Exception as e:
        return False, f"Failed to read file: {type(e).__name__}"

    if not entries:
        return False, "Session file is empty"

    has_remote_compaction = False
    has_replacement_history = False
    compaction_item_count = 0
    replacement_count = 0

    for entry in entries:
        if not isinstance(entry, dict):
            continue
        entry_type = entry.get("type")
        if entry_type in ("compaction", "compaction_summary"):
            compaction_item_count += 1

        details = entry.get("details")
        if isinstance(details, dict):
            remote = details.get("remoteCompaction")
            if isinstance(remote, dict):
                impl = remote.get("implementation")
                if impl == "responses_compaction_v2":
                    has_remote_compaction = True
                    history = remote.get("replacementHistory")
                    if isinstance(history, list) and len(history) > 0:
                        has_replacement_history = True
                        replacement_count = len(history)
            if details.get("type") in ("compaction", "compaction_summary"):
                compaction_item_count += 1

        remote = entry.get("remoteCompaction")
        if isinstance(remote, dict):
            impl = remote.get("implementation")
            if impl == "responses_compaction_v2":
                has_remote_compaction = True
                history = remote.get("replacementHistory")
                if isinstance(history, list) and len(history) > 0:
                    has_replacement_history = True
                    replacement_count = len(history)

    last_entry = entries[-1] if entries else {}
    last_is_compaction = (
        last_entry.get("type") in ("compaction", "compaction_summary") or
        (isinstance(last_entry.get("details"), dict) and last_entry["details"].get("type") in ("compaction", "compaction_summary"))
    )

    if not has_remote_compaction:
        return False, "Missing details.remoteCompaction.implementation == 'responses_compaction_v2'"
    if not has_replacement_history:
        return False, "Missing or empty replacementHistory in remoteCompaction"
    if compaction_item_count == 0 or not last_is_compaction:
        return False, "Missing final compaction item in session"

    return True, f"Valid responses_compaction_v2 session ({len(entries)} entries, {replacement_count} replacement history items, {compaction_item_count} compaction items)"

ok, msg = validate_compaction_session(sys.argv[1])
print(msg)
sys.exit(0 if ok else 1)
PY
}

# Test 1: Valid session passes
out="$(validate_fn "$valid_session")"
if ! grep -q "Valid responses_compaction_v2 session" <<<"$out"; then
  printf 'Valid session test failed: %s\n' "$out" >&2
  exit 1
fi
if grep -q "SECRET_PROMPT" <<<"$out"; then
  printf 'Valid session leaked secret text!\n' >&2
  exit 1
fi

# Test 2: Wrong implementation fails
if out="$(validate_fn "$wrong_impl_session" 2>&1)"; then
  printf 'Wrong implementation unexpectedly succeeded: %s\n' "$out" >&2
  exit 1
fi
grep -q "responses_compaction_v2" <<<"$out"

# Test 3: Empty history fails
if out="$(validate_fn "$empty_history_session" 2>&1)"; then
  printf 'Empty history unexpectedly succeeded: %s\n' "$out" >&2
  exit 1
fi
grep -q "replacementHistory" <<<"$out"

# Test 4: Missing compaction item fails
if out="$(validate_fn "$no_compaction_item_session" 2>&1)"; then
  printf 'Missing compaction item unexpectedly succeeded: %s\n' "$out" >&2
  exit 1
fi
grep -q "Missing final compaction item" <<<"$out"

# Test 5: Malformed JSONL fails
if out="$(validate_fn "$malformed_session" 2>&1)"; then
  printf 'Malformed JSONL unexpectedly succeeded: %s\n' "$out" >&2
  exit 1
fi
grep -q "Malformed JSON" <<<"$out"

# Test 6: Nonexistent file fails
if out="$(validate_fn "$nonexistent_session" 2>&1)"; then
  printf 'Nonexistent file unexpectedly succeeded: %s\n' "$out" >&2
  exit 1
fi
grep -q "File not found" <<<"$out"

# Integration tests with scripts/validate.sh (guarded to avoid recursion)
if [ "${_VALIDATE_SUBTEST_RUNNING:-0}" -eq 0 ]; then
  # Integration 1: Malformed session file fails validation with exit code 1 and summary
  set +e
  val_out="$(PI_COMPACTION_SESSION_FILE="$malformed_session" "$ROOT/scripts/validate.sh" 2>&1)"
  val_code=$?
  set -e
  if [ "$val_code" -ne 1 ]; then
    printf 'Expected validate.sh with malformed session to exit 1, got %d\n' "$val_code" >&2
    exit 1
  fi
  grep -q "Live compaction proof failed: Malformed JSON" <<<"$val_out"
  grep -q "Validation FAILED with 1 error(s)" <<<"$val_out"

  # Integration 2: Nonexistent session file fails validation with exit code 1 and summary
  set +e
  val_out="$(PI_COMPACTION_SESSION_FILE="$nonexistent_session" "$ROOT/scripts/validate.sh" 2>&1)"
  val_code=$?
  set -e
  if [ "$val_code" -ne 1 ]; then
    printf 'Expected validate.sh with nonexistent session to exit 1, got %d\n' "$val_code" >&2
    exit 1
  fi
  grep -q "Live compaction proof failed: File not found" <<<"$val_out"
  grep -q "Validation FAILED with 1 error(s)" <<<"$val_out"

  # Integration 3: Valid session file passes compaction check and reaches target blocker (exit 2) on dev host
  set +e
  val_out="$(PI_COMPACTION_SESSION_FILE="$valid_session" "$ROOT/scripts/validate.sh" 2>&1)"
  val_code=$?
  set -e
  if [ "$val_code" -ne 2 ] && [ "$val_code" -ne 0 ]; then
    printf 'Expected validate.sh with valid session to exit 2 (or 0), got %d\n' "$val_code" >&2
    exit 1
  fi
  grep -q "Live compaction proof verified: Valid responses_compaction_v2 session" <<<"$val_out"
  if grep -q "SECRET_PROMPT" <<<"$val_out"; then
    printf 'validate.sh leaked secret text from compaction session!\n' >&2
    exit 1
  fi
fi

printf '%s\n' "All Pi OpenAI compaction proof contract tests passed."
