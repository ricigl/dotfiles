# Shared instructions for Antigravity CLI and Pi

This is the single tracked shared policy for Antigravity CLI (`agy`) and Pi. Home Manager exposes this same source to Pi's global context and Antigravity's global `GEMINI.md` context. Prime has a separate policy at `home/.prime/agent/AGENTS.md`; do not merge Prime-only operating rules into this file.

## Durable repository decisions

- The target is Ubuntu WSL2 with the registered distro name exactly `Ubuntu`.
- Windows Orca 1.4.184 reaches Ubuntu only through key-authenticated SSH on `127.0.0.1:2222`.
- Repositories and worktrees belong under `/home/...`, never `/mnt/c`. Use Linux Git only.
- Orca exclusively creates, reuses, moves, and removes coding worktrees. AGY and Pi do not manage Orca worktrees.
- Ubuntu apt/system bootstrap owns systemd, OpenSSH, sshd configuration, `build-essential`, and global `python3`. Do not move those pre-relay requirements into Home Manager or a project shell.
- The default Home Manager profile owns Zsh, Starship, Git, CLI tools, Neovim, ABNT2 support, global Node 24, AGY, and Pi.
- `nix develop .#orca-prime` intentionally shadows global Node 24 with Node 22 for Prime.
- WezTerm, Herdr, Claude Code, and Codex remain isolated in the optional legacy profile.
- AGY and Pi are user-installed coding tools, not Orca worktree managers. Do not restore permission-bypass or approval-bypass aliases to the default profile.
- Never commit private keys, `authorized_keys`, credentials, installer binaries, auth, sessions, caches, generated runtime state, or `.no-mistakes/` validation evidence.
- Host-mutating bootstrap execution, authentication, publication, push, and pull-request creation require explicit human approval.
- Never use the em dash character. Use a plain dash `-` instead.
- Never automatically add an agent name as a commit co-author.
- Never manually modify `CHANGELOG.md` or auto-generated files.
- Prefer quality, simplicity, robustness, scalability, and long-term maintainability over development cost.
- For one-off operational work, use the simplest direct end-to-end path unless a repeated need justifies extra wrappers or automation.
- Reproduce bugs end to end before fixing them. Treat UI quality, lint failures, test failures, and flaky tests as first-class engineering issues.
- Explain tradeoffs and obtain explicit approval before dynamic workflows, ultra-code modes, or large subagent swarms.

## Caveman shared skill

- The shared `caveman` skill is installed for Pi under `~/.agents/skills/caveman/` and for AGY under `~/.gemini/antigravity-cli/skills/caveman/`.
- Use `/caveman ultra` for token-efficient coding-agent prompts unless the user asks for normal or full-detail output.
- Keep code, identifiers, API names, commands, and exact errors unchanged. Do not compress security warnings, irreversible confirmations, or ambiguous multi-step sequences.

## Codebase Memory MCP - required graph-first workflow

Codebase Memory is configured as the `codebase_memory` stdio MCP server for both AGY and Pi. It uses the pinned local binary `/home/ricardo/.local/bin/codebase-memory-mcp`, working directory `/home/ricardo/src`, cache `/home/ricardo/.cache/codebase-memory-mcp`, and allowed root `/home/ricardo/src`. Diagnostics remain disabled, and destructive tools remain disabled.

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

AGY can call the named `codebase_memory` tools directly. Pi normally exposes the same server through the `mcp` adapter tool: search the adapter catalog for the exact Codebase Memory tool name, then call it with the server's bounded arguments. Keep the server selection on `codebase_memory`; do not substitute an unrelated MCP server.

## Required validation

Before proposing a commit or pull request:

```bash
./scripts/validate.sh
```

Also parse `scripts/windows-orca-bootstrap.ps1`, run ShellCheck on shell scripts, and run target smoke checks in Ubuntu WSL. If the current environment cannot execute a required boundary, report it as unverified rather than fabricating success.

## Maintaining this file

Keep only durable knowledge useful to both AGY and Pi. Point to authoritative files instead of duplicating implementation details. Prime-only policy belongs in `home/.prime/agent/AGENTS.md`.
