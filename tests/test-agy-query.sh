#!/usr/bin/env bash
# Deterministic contract and behavior tests for scripts/agy-query.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/agy-query.sh"
BASE_MODULE="$ROOT/modules/home-base.nix"
README="$ROOT/README.md"
VALIDATE="$ROOT/scripts/validate.sh"

for required_file in "$SCRIPT" "$BASE_MODULE" "$README" "$VALIDATE"; do
  test -f "$required_file" || {
    printf 'Missing required file: %s\n' "$required_file" >&2
    exit 1
  }
done
test -x "$SCRIPT"

python3 - "$SCRIPT" "$BASE_MODULE" "$README" "$VALIDATE" <<'PY'
import sys
from pathlib import Path

script = Path(sys.argv[1]).read_text(encoding="utf-8")
base_module = Path(sys.argv[2]).read_text(encoding="utf-8")
readme = Path(sys.argv[3]).read_text(encoding="utf-8")
validate = Path(sys.argv[4]).read_text(encoding="utf-8")

assert '"?" = "${dotfiles}/scripts/agy-query.sh";' in base_module
assert 'gemini-3.7-flash-low' in script
assert '--print' in script
assert '--effort low' in script
assert '--output-format text' in script
assert 'briefly, clearly, and directly' in script
assert 'direct actionable instructions' in script
assert 'Use no tools unless a web search is necessary' in script
assert 'if needed, use only web-search tools' in script
assert 'Never use any other tools' in script
assert '--dangerously-skip-permissions' not in script
assert 'chrome-devtools-axi' not in script
assert 'GOOGLE_AI_SEARCH' not in script
assert 'scripts/agy-query.sh' in validate
assert 'tests/test-agy-query.sh' in validate
assert 'AGY concise terminal Q&A' in readme
assert 'gemini-3.7-flash-low' in readme

print("Static contracts for AGY concise Q&A verified.")
PY

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/agy-query-test.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
fake_agy="$fake_bin/agy"
agy_log="$tmp_dir/agy.log"

cat <<'EOF_AGY' > "$fake_agy"
#!/usr/bin/env bash
set -euo pipefail
printf 'ARG=%s\n' "$@" > "$AGY_LOG"
printf 'FAKE AGY ANSWER\n'
EOF_AGY
chmod 0755 "$fake_agy"
export AGY_LOG="$agy_log"

# Empty and whitespace-only input fail clearly.
set +e
empty_output="$("$SCRIPT" 2>&1)"
empty_status=$?
whitespace_output="$("$SCRIPT" '   ' 2>&1)"
whitespace_status=$?
set -e

test "$empty_status" -ne 0
case "$empty_output" in
  *"Usage: ? <question>"*) ;;
  *) printf 'Unexpected empty-query output: %s\n' "$empty_output" >&2; exit 1 ;;
esac

test "$whitespace_status" -ne 0
case "$whitespace_output" in
  *"question cannot be empty"*) ;;
  *) printf 'Unexpected whitespace-query output: %s\n' "$whitespace_output" >&2; exit 1 ;;
esac

# The wrapper passes one joined question and the requested AGY options.
question='how do I undo the last local Git commit?'
output="$(PATH="$fake_bin:$PATH" "$SCRIPT" how do I undo the last local Git commit?)"
case "$output" in
  *"FAKE AGY ANSWER"*) ;;
  *) printf 'Unexpected AGY output: %s\n' "$output" >&2; exit 1 ;;
esac

log_content="$(cat "$agy_log")"
for expected_arg in \
  'ARG=--model' \
  'ARG=gemini-3.7-flash-low' \
  'ARG=--effort' \
  'ARG=low' \
  'ARG=--output-format' \
  'ARG=text'; do
  case "$log_content" in
    *"$expected_arg"*) ;;
    *) printf 'Missing AGY argument %s:\n%s\n' "$expected_arg" "$log_content" >&2; exit 1 ;;
  esac
done
case "$log_content" in
  *"ARG=--print=You are a concise terminal question-and-answer assistant."*"User question: $question"*) ;;
  *) printf 'Question was not passed in the prompt:\n%s\n' "$log_content" >&2; exit 1 ;;
esac

# Missing AGY is reported without invoking another tool.
set +e
missing_output="$(PATH="$tmp_dir/empty-path:/usr/bin:/bin" "$SCRIPT" "test question" 2>&1)"
missing_status=$?
set -e
test "$missing_status" -ne 0
case "$missing_output" in
  *"agy CLI is not installed or not in PATH"*) ;;
  *) printf 'Unexpected missing-AGY output: %s\n' "$missing_output" >&2; exit 1 ;;
esac

printf '%s\n' "All AGY concise Q&A contract and behavioral tests passed."
