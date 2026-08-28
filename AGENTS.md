# Shared instructions for Antigravity CLI, Pi, and Prime Agent

This is the single tracked shared policy for Antigravity CLI (`agy`), Pi, and Prime Agent. Home Manager exposes this same source to each harness's global policy path. Firstmate has its own project-level `AGENTS.md` inside `~/firstmate`; this file governs the shared WSL agent environment and must not be replaced by Firstmate's distro policy.

## Durable repository decisions

- Repositories and worktrees belong under `/home/...`, never `/mnt/c`. Use Linux Git only.
- Firstmate owns creation, reuse, movement, and removal of project and crew worktrees under `~/firstmate/projects` through its reviewed Linux Treehouse backend.
- AGY, Pi, and Prime must never run `git worktree add`, `git worktree remove`, `git worktree prune`, Treehouse allocation, or another worktree manager. Only Firstmate's orchestrator may allocate its crew worktrees.
- Agents may operate only inside a worktree explicitly assigned by Firstmate and exposed through the Herdr/SSH workflow.
- Firstmate's project coordination home is `~/firstmate`; project roots are under `~/firstmate/projects`.
- Firstmate must use its reviewed Linux `tmux`/Treehouse backend for project and crew worktrees. 
- Never commit private keys, `authorized_keys`, credentials, installer binaries, auth, sessions, caches, generated runtime state, project runtime state, or `.no-mistakes/` evidence.
- Host-mutating bootstrap execution, authentication, publication, push, and pull-request creation require explicit human approval.
- Never use the em dash character. Use a plain dash `-` instead.
- Never automatically add an agent name as a commit co-author.
- Never manually modify `CHANGELOG.md` or auto-generated files.
- Prefer quality, simplicity, robustness, scalability, and long-term maintainability over development cost.
- For one-off operational work, use the simplest direct end-to-end path unless a repeated need justifies extra wrappers or automation.
- Reproduce bugs end to end before fixing them.
- Treat UI quality, lint failures, test failures, and flaky tests as first-class engineering issues.
- Explain tradeoffs and obtain explicit approval before dynamic workflows, ultra-code modes, or large subagent swarms.

## Harness and installation boundaries

- Never run any harness or installer as root.
- Keep authentication, sessions, caches, logs, downloads, daemon sockets, and generated state outside this repository.

## Safety

- Do not authenticate services, publish artifacts, upload traces, install software, modify GitHub, or expose a network listener without explicit approval.
- Use `gh-axi` read-only initially: list, view, search, checks, logs, and repository context only. Do not create branches, merge, approve, release, edit workflows, or mutate repository settings, unless explicitly requested.
- Run Lavish only on `127.0.0.1` with `--no-open`. Never use `lavish-axi share`, hooks, plugins, public sharing, or non-loopback binding.

## Optional ADHD mode

- Activate only after `/skill:i-have-adhd` or an explicit request for ADHD mode.
- `normal mode` or `stop adhd mode` disables it for the session.
- Never omit safety warnings, uncertainty, blockers, failures, required steps, or validation evidence to satisfy brevity, list limits, or time-estimate rules.

## Codebase Memory MCP - token-efficient workflow

Codebase Memory is configured as the `codebase_memory` stdio MCP server for AGY, Pi, and Prime. It uses the pinned Nix package `codebase-memory-mcp` on PATH, working directory `/home/ricardo/src`, cache `/home/ricardo/.cache/codebase-memory-mcp`, and allowed root `/home/ricardo`. Diagnostics remain disabled, and destructive tools remain disabled. Index only explicit repositories under `/home/ricardo/src` or `/home/ricardo/firstmate/projects`; never index `/home/ricardo` itself or credential/config directories.

Use Codebase Memory for unfamiliar, multi-file, or impact-analysis work. Skip it for trivial one-file edits, known paths, documentation-only changes, and simple commands.

For non-trivial repository work, use this bounded order:

1. Resolve the current repository/worktree and check `index_status`.
2. Use `get_architecture` once with `aspects=["overview"]`.
3. Use narrow `search_graph` or `search_code` queries with bounded results, normally `limit <= 10`.
4. Use `trace_path` for relevant callers, callees, or impact with depth `<= 3`.
5. Use `get_code_snippet` only after finding the exact qualified symbol.
6. Read only the directly relevant source files and line ranges.
7. Run `check_index_coverage` before negative or exhaustive claims.
8. After edits, use `detect_changes` to review affected symbols and blast radius.

Use `search_graph` for definitions and relationships. Use `search_code` for literal text and configuration searches. Use `query_graph` only for genuine multi-hop or aggregation queries with an explicit small `LIMIT`. Do not request full architecture, broad source windows, or automatic pagination without evidence that it is needed.

Treat Codebase Memory as a discovery index, not the final source of truth. Verify conclusions against the current worktree. Never index `/home`, `/mnt/c`, credentials, sessions, caches, unrelated worktrees, or generated runtime state. Never paste indexed source into unrelated channels or external services.

If MCP is unavailable, say so and use bounded direct repository search rather than pretending that graph results exist.

AGY can call named Codebase Memory tools directly. Pi normally exposes the server through the `mcp` adapter tool. Prime exposes its generic MCP API. Keep server selection on `codebase_memory` and use bounded read-only calls.


## General engineering rules

- When writing commit messages, never automatically add the agent name as a co-author.
- Never manually modify `CHANGELOG.md` files or files marked as auto-generated.
- For bug fixes, first reproduce the bug in an end-to-end setting as closely aligned with the end-user experience as possible.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection. If something clearly looks off, try to get it fixed along the way.
- Apply the same high standard to engineering excellence: fix lint failures, test failures, and test flakiness encountered during work.

## Maintaining this file

Keep only durable knowledge useful to all three harnesses. Client-specific syntax belongs in client-specific configuration and documentation. Firstmate's project-distro policy belongs in `~/firstmate/AGENTS.md`; do not duplicate its internal operational instructions here.
