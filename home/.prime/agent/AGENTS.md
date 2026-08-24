# Orca and Prime operating policy

- Work only inside the current Orca-assigned worktree.
- Orca exclusively creates, reuses, moves, and removes coding worktrees. Never run `git worktree add`, `git worktree remove`, `git worktree prune`, or another worktree manager in an Orca project.
- Never run Prime as root. Prime is not a sandbox; generated Python, shell commands, skills, workers, and the persistent IPython kernel execute with the Ubuntu user's permissions.
- Do not authenticate services, publish artifacts, upload traces, install software, modify GitHub, or expose a network listener without explicit approval.
- Use `gh-axi` read-only initially: list, view, search, checks, logs, and repository context only. Do not create branches, merge, approve, release, edit workflows, or mutate repository settings.
- Run Lavish only on `127.0.0.1` with `--no-open`. Never use `lavish-axi share`, hooks, plugins, public sharing, or non-loopback binding.
- Do not create recursive agents, persistent goals, schedules, heartbeats, autonomous loops, or harness refinements unless explicitly requested.
- Preserve complete engineering evidence: architecture, risks, alternatives, commands, tests, failures, uncertainty, blockers, and security findings.

## Optional ADHD mode

- Do not activate `i-have-adhd` automatically.
- Activate only after `/skill:i-have-adhd` or an explicit request for ADHD mode.
- `normal mode` or `stop adhd mode` disables it for the session.
- It changes presentation only, never permissions or engineering scope.
- Never omit safety warnings, uncertainty, blockers, failures, required steps, or validation evidence to satisfy brevity, list limits, or time-estimate rules.

## Codebase Memory MCP — token-efficient workflow

- Use Codebase Memory for unfamiliar, multi-file, or impact-analysis tasks.
- Skip it for trivial one-file edits, known paths, documentation-only changes, and simple commands.
- `auto_index=true` and `auto_watch=true` are intentional runtime settings. Do not toggle them from this policy.
- Resolve the current repository/worktree first and use the exact Codebase Memory project returned by `list_projects`.
- Call `index_status` before manually indexing. Only call `index_repository` when the project is missing or stale; use fast mode and `persistence=false`.
- For unfamiliar repositories, use this order:
  1. `index_status`
  2. `get_architecture` with `aspects=["overview"]`, once
  3. `search_graph` with a narrow query, `limit <= 10`, and `detail="ids"`
  4. `trace_path` for callers/callees or impact, with `depth <= 3` and a bounded limit
  5. `get_code_snippet` only after finding the exact qualified symbol
  6. Read only the relevant source files and line ranges directly
- Use `search_graph` for definitions and relationships. Use `search_code` for literal text/config searches, initially with `mode="compact"` or `mode="files"`.
- Use `query_graph` only for genuine multi-hop or aggregation queries, and always include an explicit small `LIMIT`.
- Do not request `all` architecture aspects, full source windows, or automatic pagination unless the first result proves they are needed.
- If a result has `has_more`, fetch more only when the missing results are relevant to the task.
- Run `check_index_coverage` for files used in the conclusion before making negative or exhaustive claims.
- After edits, use `detect_changes` to review the affected symbols and blast radius.
- Treat Codebase Memory as a discovery/index, not the final source of truth. Verify implementation details against the current worktree.
- Never index `/home`, `/mnt/c`, credentials, sessions, caches, unrelated worktrees, or generated runtime state.
- Never paste indexed source into unrelated channels or external services.
- Keep MCP responses and engineering summaries compact: report paths, symbols, line ranges, risks, and next actions instead of dumping source.
