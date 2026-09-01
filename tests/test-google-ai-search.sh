#!/usr/bin/env bash
# Focused deterministic contract and behavior tests for scripts/google-ai-search.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/google-ai-search.sh"
BASE_MODULE="$ROOT/modules/home-base.nix"
README="$ROOT/README.md"
VALIDATE="$ROOT/scripts/validate.sh"

test -f "$SCRIPT"
test -x "$SCRIPT"
test -f "$BASE_MODULE"
test -f "$README"
test -f "$VALIDATE"

# ------------------------------------------------------------------------------
# 1. Static Contract Checks
# ------------------------------------------------------------------------------
python3 - "$SCRIPT" "$BASE_MODULE" "$README" "$VALIDATE" <<'PY'
import sys
from pathlib import Path

script_content = Path(sys.argv[1]).read_text(encoding="utf-8")
base_module = Path(sys.argv[2]).read_text(encoding="utf-8")
readme = Path(sys.argv[3]).read_text(encoding="utf-8")
validate = Path(sys.argv[4]).read_text(encoding="utf-8")

# 1.1 Alias contract in modules/home-base.nix
assert '"?" = "${dotfiles}/scripts/google-ai-search.sh";' in base_module, "home-base.nix must declare ? alias"
assert 'CHROME_DEVTOOLS_AXI_HEADED = "1";' in base_module, "home-base.nix must keep global CHROME_DEVTOOLS_AXI_HEADED=1 unchanged"

# 1.2 Isolation & security contracts in scripts/google-ai-search.sh
assert 'CHROME_DEVTOOLS_AXI_HEADED=0' in script_content, "scripts/google-ai-search.sh must inline CHROME_DEVTOOLS_AXI_HEADED=0"
assert 'GOOGLE_AI_SEARCH_SESSION' in script_content, "scripts/google-ai-search.sh must support session override"
assert 'google-ai-search' in script_content, "scripts/google-ai-search.sh must default session to google-ai-search"
assert 'GOOGLE_AI_SEARCH_PROFILE_DIR' in script_content, "scripts/google-ai-search.sh must support profile dir override"
assert 'google-ai-search/chrome-profile' in script_content, "scripts/google-ai-search.sh must default to isolated profile"
assert 'chmod 0700' in script_content, "scripts/google-ai-search.sh must enforce 0700 directory permissions"
assert 'GOOGLE_AI_SEARCH_AXI_BIN' in script_content, "scripts/google-ai-search.sh must support AXI bin override"
assert 'GOOGLE_AI_SEARCH_WAIT_MS' in script_content, "scripts/google-ai-search.sh must support wait ms override"
assert 'GOOGLE_AI_SEARCH_WAIT_MS must be an integer between 0 and 60000' in script_content, "wait ms must be bounded before JavaScript interpolation"
assert 'urllib.parse.quote_plus' in script_content or 'encodeURIComponent' in script_content, "scripts/google-ai-search.sh must URL-encode queries safely"
assert 'open "$SEARCH_URL"' in script_content, "scripts/google-ai-search.sh must open the search URL before run"
assert 'await page.wait(' in script_content, "scripts/google-ai-search.sh must use await page.wait()"
assert 'await page.eval(' in script_content, "scripts/google-ai-search.sh must use await page.eval()"
assert 'console.log(JSON.stringify(' in script_content, "scripts/google-ai-search.sh must print output with console.log"
assert 'GOOGLE_AI_SEARCH_W3M_FALLBACK' in script_content, "scripts/google-ai-search.sh must support w3m fallback"
assert 'unusual-traffic check' in script_content, "scripts/google-ai-search.sh must identify Google unusual-traffic blocks"

# 1.3 Validation script contract
assert 'scripts/google-ai-search.sh' in validate, "validate.sh must include scripts/google-ai-search.sh in syntax checks"
assert 'tests/test-google-ai-search.sh' in validate, "validate.sh must execute test-google-ai-search.sh subtest"

print("Static contracts for Google AI Search verified.")
PY

# ------------------------------------------------------------------------------
# 2. Behavioral Unit Tests with Fake AXI and Fake w3m
# ------------------------------------------------------------------------------
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/google-ai-search-test.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

fake_bin_dir="$tmp_dir/bin"
mkdir -p "$fake_bin_dir"

fake_profile_dir="$tmp_dir/profile"
mkdir -p "$fake_profile_dir"

fake_axi="$fake_bin_dir/fake-axi"
fake_w3m="$fake_bin_dir/w3m"
log_file="$tmp_dir/axi.log"
w3m_log="$tmp_dir/w3m.log"

# Test 2.1: Empty query fails non-zero with usage message
set +e
empty_out="$("$SCRIPT" 2>&1)"
empty_code=$?
set -e
test "$empty_code" -ne 0
case "$empty_out" in
  *"Usage: ?"*) ;;
  *) printf 'Unexpected output on empty query: %s\n' "$empty_out" >&2; exit 1 ;;
esac

# Test 2.2: Whitespace-only query fails non-zero with error message
set +e
ws_out="$("$SCRIPT" "   " 2>&1)"
ws_code=$?
set -e
test "$ws_code" -ne 0
case "$ws_out" in
  *"search query cannot be empty"*) ;;
  *) printf 'Unexpected output on whitespace query: %s\n' "$ws_out" >&2; exit 1 ;;
esac

# Test 2.3: Missing AXI CLI fails non-zero with clear error
set +e
missing_out="$(GOOGLE_AI_SEARCH_AXI_BIN="$tmp_dir/nonexistent-axi" "$SCRIPT" "test query" 2>&1)"
missing_code=$?
set -e
test "$missing_code" -ne 0
case "$missing_out" in
  *"not installed or not in PATH"*) ;;
  *) printf 'Unexpected output on missing AXI CLI: %s\n' "$missing_out" >&2; exit 1 ;;
esac

# Test 2.4: Invalid wait values cannot be interpolated into the DevTools script
set +e
invalid_wait_out="$(GOOGLE_AI_SEARCH_AXI_BIN="/bin/true" GOOGLE_AI_SEARCH_WAIT_MS='5000); process.exit(1); //' "$SCRIPT" "test query" 2>&1)"
invalid_wait_code=$?
set -e
test "$invalid_wait_code" -ne 0
case "$invalid_wait_out" in
  *"GOOGLE_AI_SEARCH_WAIT_MS must be an integer between 0 and 60000"*) ;;
  *) printf 'Unexpected output on invalid wait value: %s\n' "$invalid_wait_out" >&2; exit 1 ;;
esac

# Test 2.5: Query URL encoding & Environment Isolation
cat <<'EOF_AXI' > "$fake_axi"
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = "open" ]; then
  printf 'OPEN_URL=%s\n' "${2:-}" >> "$TEST_LOG"
  exit 0
elif [ "$1" = "run" ]; then
  payload="$(cat)"
  printf 'HEADED=%s\n' "${CHROME_DEVTOOLS_AXI_HEADED:-<UNSET>}" >> "$TEST_LOG"
  printf 'SESSION=%s\n' "${CHROME_DEVTOOLS_AXI_SESSION:-<UNSET>}" >> "$TEST_LOG"
  printf 'USER_DATA_DIR=%s\n' "${CHROME_DEVTOOLS_AXI_USER_DATA_DIR:-<UNSET>}" >> "$TEST_LOG"
  printf 'PAYLOAD=%s\n' "$payload" >> "$TEST_LOG"
  printf '%s\n' "$MOCK_AXI_RESPONSE"
else
  exit 1
fi
EOF_AXI
chmod +x "$fake_axi"

MOCK_RESPONSE='{"found": true, "title": "AI Overview", "text": "Quantum computing leverages qubits in superposition.\nEntanglement connects states.", "citations": ["https://example.com/quantum", "https://nature.com/article1", "https://example.com/quantum"]}'
export TEST_LOG="$log_file"
export MOCK_AXI_RESPONSE="$MOCK_RESPONSE"

rm -f "$log_file"
success_out="$(
  GOOGLE_AI_SEARCH_AXI_BIN="$fake_axi" \
  GOOGLE_AI_SEARCH_PROFILE_DIR="$fake_profile_dir" \
  GOOGLE_AI_SEARCH_SESSION="test-ai-session" \
  GOOGLE_AI_SEARCH_WAIT_MS="3500" \
  "$SCRIPT" "quantum computing & ai? + tests/100%"
)"

# Verify output format
case "$success_out" in
  *"AI Overview:"*) ;;
  *) printf 'Missing title in success output: %s\n' "$success_out" >&2; exit 1 ;;
esac
case "$success_out" in
  *"Quantum computing leverages qubits in superposition."*) ;;
  *) printf 'Missing body text in success output: %s\n' "$success_out" >&2; exit 1 ;;
esac
case "$success_out" in
  *"Sources:"*) ;;
  *) printf 'Missing Sources header in success output: %s\n' "$success_out" >&2; exit 1 ;;
esac
case "$success_out" in
  *"- https://example.com/quantum"*) ;;
  *) printf 'Missing first citation in success output: %s\n' "$success_out" >&2; exit 1 ;;
esac
case "$success_out" in
  *"- https://nature.com/article1"*) ;;
  *) printf 'Missing second citation in success output: %s\n' "$success_out" >&2; exit 1 ;;
esac

# Verify isolation in log
log_content="$(cat "$log_file")"
case "$log_content" in
  *"OPEN_URL=https://www.google.com/search?q=quantum+computing+%26+ai%3F+%2B+tests%2F100%25"*) ;;
  *) printf 'Search URL was not properly URL encoded: %s\n' "$log_content" >&2; exit 1 ;;
esac
case "$log_content" in
  *"HEADED=0"*) ;;
  *) printf 'Failed to enforce CHROME_DEVTOOLS_AXI_HEADED=0\n' >&2; exit 1 ;;
esac
case "$log_content" in
  *"SESSION=test-ai-session"*) ;;
  *) printf 'Failed to pass session name\n' >&2; exit 1 ;;
esac
case "$log_content" in
  *"USER_DATA_DIR=$fake_profile_dir"*) ;;
  *) printf 'Failed to pass isolated profile dir\n' >&2; exit 1 ;;
esac
case "$log_content" in
  *"quantum+computing+%26+ai%3F+%2B+tests%2F100%25"*) ;;
  *) printf 'Query was not properly URL encoded: %s\n' "$log_content" >&2; exit 1 ;;
esac
case "$log_content" in
  *"await page.wait(3500)"*) ;;
  *) printf 'Wait ms override not reflected: %s\n' "$log_content" >&2; exit 1 ;;
esac

# Verify profile dir permissions mode 0700
prof_mode="$(python3 -c "import os, stat; print(oct(stat.S_IMODE(os.stat('$fake_profile_dir').st_mode)))")"
if [ "$prof_mode" != "0o700" ] && [ "$prof_mode" != "0700" ]; then
  printf 'Profile directory permissions %s != 0700\n' "$prof_mode" >&2
  exit 1
fi

# Test 2.6: No Overview behavior (without w3m fallback)
export MOCK_AXI_RESPONSE='{"found": false}'
set +e
no_overview_out="$(
  GOOGLE_AI_SEARCH_AXI_BIN="$fake_axi" \
  GOOGLE_AI_SEARCH_PROFILE_DIR="$fake_profile_dir" \
  "$SCRIPT" "obscure topic without overview" 2>&1
)"
no_overview_code=$?
set -e
test "$no_overview_code" -ne 0
case "$no_overview_out" in
  *"No AI Overview found for query: obscure topic without overview"*) ;;
  *) printf 'Missing no overview message: %s\n' "$no_overview_out" >&2; exit 1 ;;
esac
case "$no_overview_out" in
  *"Search URL: https://www.google.com/search?q=obscure+topic+without+overview"*) ;;
  *) printf 'Missing search URL in output: %s\n' "$no_overview_out" >&2; exit 1 ;;
esac

# Test 2.7: No Overview behavior with optional w3m fallback enabled
cat <<'EOF_W3M' > "$fake_w3m"
#!/usr/bin/env bash
printf 'W3M_CALLED=%s\n' "$*" >> "$TEST_W3M_LOG"
exit 0
EOF_W3M
chmod +x "$fake_w3m"

export TEST_W3M_LOG="$w3m_log"
rm -f "$w3m_log"
set +e
(
  export PATH="$fake_bin_dir:$PATH"
  GOOGLE_AI_SEARCH_AXI_BIN="$fake_axi" \
  GOOGLE_AI_SEARCH_PROFILE_DIR="$fake_profile_dir" \
  GOOGLE_AI_SEARCH_W3M_FALLBACK="1" \
  "$SCRIPT" "fallback query"
)
set -e
test -f "$w3m_log"
w3m_log_content="$(cat "$w3m_log")"
case "$w3m_log_content" in
  *"W3M_CALLED=https://www.google.com/search?q=fallback+query"*) ;;
  *) printf 'w3m was not invoked with search URL: %s\n' "$w3m_log_content" >&2; exit 1 ;;
esac

# Test 2.8: Browser automation failure / timeout
cat <<'EOF_FAIL' > "$fake_axi"
#!/usr/bin/env bash
exit 1
EOF_FAIL
chmod +x "$fake_axi"

set +e
fail_out="$(
  GOOGLE_AI_SEARCH_AXI_BIN="$fake_axi" \
  GOOGLE_AI_SEARCH_PROFILE_DIR="$fake_profile_dir" \
  "$SCRIPT" "query that times out" 2>&1
)"
fail_code=$?
set -e
test "$fail_code" -ne 0
case "$fail_out" in
  *"browser automation failed or timed out"*) ;;
  *) printf 'Unexpected failure output: %s\n' "$fail_out" >&2; exit 1 ;;
esac

# Test 2.9: Malformed extractor output
cat <<'EOF_MALFORMED' > "$fake_axi"
#!/usr/bin/env bash
printf '%s\n' "NOT_VALID_JSON_AT_ALL"
exit 0
EOF_MALFORMED
chmod +x "$fake_axi"

set +e
malformed_out="$(
  GOOGLE_AI_SEARCH_AXI_BIN="$fake_axi" \
  GOOGLE_AI_SEARCH_PROFILE_DIR="$fake_profile_dir" \
  "$SCRIPT" "malformed query" 2>&1
)"
malformed_code=$?
set -e
test "$malformed_code" -ne 0
case "$malformed_out" in
  *"malformed extractor output from browser session"*) ;;
  *) printf 'Unexpected malformed output: %s\n' "$malformed_out" >&2; exit 1 ;;
esac

# Test 2.10: Google unusual-traffic block is distinct from no overview
cat <<'EOF_BLOCKED' > "$fake_axi"
#!/usr/bin/env bash
if [ "$1" = "open" ]; then
  exit 0
fi
printf '%s\n' '{"blocked": true}'
EOF_BLOCKED
chmod +x "$fake_axi"

set +e
blocked_out="$(
  GOOGLE_AI_SEARCH_AXI_BIN="$fake_axi" \
  GOOGLE_AI_SEARCH_PROFILE_DIR="$fake_profile_dir" \
  "$SCRIPT" "blocked query" 2>&1
)"
blocked_code=$?
set -e
test "$blocked_code" -eq 3
case "$blocked_out" in
  *"Google blocked this automated request with an unusual-traffic check."*) ;;
  *) printf 'Missing Google block diagnostic: %s\n' "$blocked_out" >&2; exit 1 ;;
esac
case "$blocked_out" in
  *"does not bypass CAPTCHA"*) ;;
  *) printf 'Missing Google protection boundary: %s\n' "$blocked_out" >&2; exit 1 ;;
esac

printf '%s\n' "All Google AI Search contract and behavioral tests passed."
