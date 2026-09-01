#!/usr/bin/env bash
# Google AI Search shell workflow using chrome-devtools-axi.
# Executes an isolated, headless Chrome DevTools session to extract
# rendered AI Overview and deduplicated source citations.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  printf '%s\n' "Usage: ? <search query>" >&2
  exit 1
fi

QUERY="$*"
if [ -z "${QUERY//[[:space:]]/}" ]; then
  printf '%s\n' "Error: search query cannot be empty." >&2
  printf '%s\n' "Usage: ? <search query>" >&2
  exit 1
fi

AXI_BIN="${GOOGLE_AI_SEARCH_AXI_BIN:-chrome-devtools-axi}"
if ! command -v "$AXI_BIN" >/dev/null 2>&1 && [ ! -x "$AXI_BIN" ]; then
  printf '%s\n' "Error: chrome-devtools-axi CLI is not installed or not in PATH ($AXI_BIN)." >&2
  exit 1
fi

PROFILE_DIR="${GOOGLE_AI_SEARCH_PROFILE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/google-ai-search/chrome-profile}"
mkdir -p "$PROFILE_DIR"
chmod 0700 "$PROFILE_DIR" 2>/dev/null || true

SESSION_NAME="${GOOGLE_AI_SEARCH_SESSION:-google-ai-search}"
WAIT_MS="${GOOGLE_AI_SEARCH_WAIT_MS:-5000}"
if ! [[ "$WAIT_MS" =~ ^[0-9]+$ ]] || [ "$WAIT_MS" -gt 60000 ]; then
  printf '%s\n' "Error: GOOGLE_AI_SEARCH_WAIT_MS must be an integer between 0 and 60000." >&2
  exit 1
fi

ENCODED_QUERY="$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote_plus(sys.argv[1]))' "$QUERY")"
SEARCH_URL="https://www.google.com/search?q=${ENCODED_QUERY}"
JSON_SEARCH_URL="$(python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$SEARCH_URL")"

JS_EXTRACTOR='(function() {
  var currentUrl = String(window.location.href || "");
  var pageText = (document.body && (document.body.innerText || document.body.textContent) || "").trim();
  if (/\/sorry(?:\/|$)/i.test(currentUrl) || /unusual traffic|not a robot|automated queries/i.test(pageText)) {
    return { blocked: true };
  }

  var headingPatterns = [
    /ai\s*overview/i,
    /vis[aã]o\s*geral/i,
    /resumo\s*(de|da|por)?\s*ia/i
  ];

  function matchesHeading(text) {
    if (!text) return false;
    var t = text.trim();
    return headingPatterns.some(function(p) { return p.test(t); });
  }

  var container = null;
  var dataSelectors = [
    "[data-attrid*=\"ai_overview\" i]",
    "[data-attrid*=\"overview\" i]",
    "[data-attrid*=\"wa:/ai_overview\" i]",
    "[data-entityname*=\"AI Overview\" i]",
    "[data-entityname*=\"Visão geral\" i]"
  ];

  for (var i = 0; i < dataSelectors.length; i++) {
    try {
      var el = document.querySelector(dataSelectors[i]);
      if (el && (el.innerText || el.textContent || "").trim().length > 20) {
        container = el;
        break;
      }
    } catch (e) {}
  }

  if (!container) {
    var headings = Array.from(document.querySelectorAll("h1, h2, h3, h4, h5, [role=\"heading\"], [aria-label]"));
    for (var j = 0; j < headings.length; j++) {
      var h = headings[j];
      var text = h.innerText || h.textContent || h.getAttribute("aria-label") || "";
      if (matchesHeading(text)) {
        var cur = h;
        var best = null;
        for (var k = 0; k < 6 && cur && cur !== document.body; k++) {
          cur = cur.parentElement;
          if (cur) {
            var curText = (cur.innerText || cur.textContent || "").trim();
            if (curText.length > text.trim().length + 20) {
              best = cur;
              if (cur.tagName === "SECTION" || cur.tagName === "ARTICLE" || cur.getAttribute("data-attrid")) {
                break;
              }
            }
          }
        }
        if (best) {
          container = best;
          break;
        }
      }
    }
  }

  if (!container) {
    return { found: false };
  }

  var links = Array.from(container.querySelectorAll("a[href]"));
  var citations = [];
  var seenUrls = {};

  for (var m = 0; m < links.length; m++) {
    var a = links[m];
    var href = a.getAttribute("href") || a.href || "";
    if (!href || href.startsWith("#") || href.startsWith("javascript:")) continue;
    var fullUrl = href;
    try {
      fullUrl = new URL(href, window.location.href).href;
    } catch (e) {
      continue;
    }

    try {
      var parsed = new URL(fullUrl);
      var host = parsed.hostname.toLowerCase();
      if (host.endsWith("google.com") || host.endsWith("google.com.br") || host.endsWith("gstatic.com") || host.endsWith("googleusercontent.com")) {
        if (parsed.pathname === "/url" && parsed.searchParams.has("q")) {
          var actual = parsed.searchParams.get("q");
          if (actual && actual.startsWith("http") && !seenUrls[actual]) {
            seenUrls[actual] = true;
            citations.push(actual);
          }
        }
        continue;
      }
      var clean = parsed.origin + parsed.pathname + parsed.search;
      if (!seenUrls[clean]) {
        seenUrls[clean] = true;
        citations.push(clean);
      }
    } catch (e) {}
  }

  var ignoredTags = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, SVG: 1, BUTTON: 1 };
  function extractText(node) {
    if (!node) return "";
    if (node.nodeType === 3) {
      return node.textContent || "";
    }
    if (node.nodeType !== 1) return "";
    if (ignoredTags[node.tagName]) return "";

    var res = "";
    var isBlock = /^(P|DIV|LI|H[1-6]|TR|SECTION|ARTICLE|BLOCKQUOTE)$/i.test(node.tagName);
    for (var n = 0; n < node.childNodes.length; n++) {
      res += extractText(node.childNodes[n]);
    }
    res = res.replace(/[ \t]+/g, " ");
    if (isBlock) {
      return "\n" + res.trim() + "\n";
    }
    return res;
  }

  var rawText = extractText(container);
  var rawLines = rawText.split("\n").map(function(l) { return l.trim(); }).filter(Boolean);

  if (rawLines.length > 0 && matchesHeading(rawLines[0])) {
    rawLines.shift();
  }

  var cleanedLines = [];
  var footerPattern = /^(generative ai is experimental|a ia generativa é experimental|learn more|saiba mais|feedback|enviar feedback|share|compartilhar)$/i;
  for (var p = 0; p < rawLines.length; p++) {
    if (footerPattern.test(rawLines[p])) continue;
    cleanedLines.push(rawLines[p]);
  }

  var textResult = cleanedLines.join("\n\n");
  if (!textResult || textResult.length < 5) {
    return { found: false };
  }

  return {
    found: true,
    title: "AI Overview",
    text: textResult,
    citations: citations
  };
})()'

JSON_JS_EXTRACTOR="$(python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$JS_EXTRACTOR")"

AXI_SCRIPT="$(cat <<AXI_EOF
await page.wait(${WAIT_MS});
const result = await page.eval(${JSON_JS_EXTRACTOR});
console.log(JSON.stringify(result));
AXI_EOF
)"

AXI_CMD=(
  env
  "CHROME_DEVTOOLS_AXI_HEADED=0"
  "CHROME_DEVTOOLS_AXI_SESSION=$SESSION_NAME"
  "CHROME_DEVTOOLS_AXI_USER_DATA_DIR=$PROFILE_DIR"
  "$AXI_BIN"
)

if ! "${AXI_CMD[@]}" open "$SEARCH_URL" >/dev/null; then
  printf '%s\n' "Error: browser automation failed or timed out while opening the search page." >&2
  exit 1
fi

AXI_OUTPUT="$(
  "${AXI_CMD[@]}" run <<< "$AXI_SCRIPT"
)" || {
  printf '%s\n' "Error: browser automation failed or timed out." >&2
  exit 1
}

set +e
PARSE_RESULT="$(
  python3 - "$AXI_OUTPUT" "$QUERY" "$SEARCH_URL" <<'PY'
import sys
import json

raw = sys.argv[1].strip()
query = sys.argv[2]
search_url = sys.argv[3]

if not raw:
    sys.exit(10)

data = None
for line in reversed(raw.splitlines()):
    line = line.strip()
    if line.startswith("{") and line.endswith("}"):
        try:
            data = json.loads(line)
            break
        except Exception:
            continue

if data is None:
    try:
        data = json.loads(raw)
    except Exception:
        sys.exit(10)

if not isinstance(data, dict):
    sys.exit(10)

if data.get("blocked"):
    print("Google blocked this automated request with an unusual-traffic check.")
    print("No AI Overview was extracted.")
    print(f"Search URL: {search_url}")
    print("The script does not bypass CAPTCHA, bot checks, or other Google protections.")
    sys.exit(3)
elif data.get("found"):
    title = data.get("title") or "AI Overview"
    text = data.get("text", "").strip()
    citations = data.get("citations", [])

    print(f"{title}:\n")
    print(text)
    if citations and isinstance(citations, list) and len(citations) > 0:
        print("\nSources:")
        for cite in citations:
            print(f"- {cite}")
    sys.exit(0)
else:
    print(f"No AI Overview found for query: {query}")
    print(f"Search URL: {search_url}")
    sys.exit(2)
PY
)"
PARSE_STATUS=$?
set -e

if [ "$PARSE_STATUS" -eq 0 ]; then
  printf '%s\n' "$PARSE_RESULT"
  exit 0
elif [ "$PARSE_STATUS" -eq 2 ]; then
  printf '%s\n' "$PARSE_RESULT"
  if [ "${GOOGLE_AI_SEARCH_W3M_FALLBACK:-0}" = "1" ] || [ "${GOOGLE_AI_SEARCH_FALLBACK_W3M:-0}" = "1" ]; then
    if command -v w3m >/dev/null 2>&1; then
      printf '%s\n' "Falling back to w3m..."
      exec w3m "$SEARCH_URL"
    fi
  fi
  exit 2
elif [ "$PARSE_STATUS" -eq 3 ]; then
  printf '%s\n' "$PARSE_RESULT" >&2
  exit 3
else
  printf '%s\n' "Error: malformed extractor output from browser session." >&2
  exit 1
fi
