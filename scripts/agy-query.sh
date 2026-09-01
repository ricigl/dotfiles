#!/usr/bin/env bash
# Concise terminal question-and-answer wrapper for Antigravity CLI.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  printf '%s\n' "Usage: ? <question>" >&2
  exit 1
fi

QUESTION="$*"
if [ -z "${QUESTION//[[:space:]]/}" ]; then
  printf '%s\n' "Error: question cannot be empty." >&2
  printf '%s\n' "Usage: ? <question>" >&2
  exit 1
fi

if ! command -v agy >/dev/null 2>&1; then
  printf '%s\n' "Error: agy CLI is not installed or not in PATH." >&2
  exit 1
fi

PROMPT="You are a concise terminal question-and-answer assistant. Answer briefly, clearly, and directly. Avoid greetings, repetition, filler, and long background. For programming questions, give direct actionable instructions, exact commands, or minimal code first, followed only by necessary explanation. State important assumptions or uncertainty in one short sentence. Use no tools unless a web search is necessary; if needed, use only web-search tools. Never use any other tools. Do not modify files or perform actions unless the user explicitly asks. User question: $QUESTION"

exec agy \
  --model gemini-3.7-flash-low \
  --effort low \
  --output-format text \
  --print="$PROMPT"
