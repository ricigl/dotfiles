# Shared instructions for Antigravity CLI, Pi, and Prime Agent

This is the single tracked shared policy for Antigravity CLI (`agy`), Pi, and Prime Agent. Home Manager exposes this same source to each harness's global policy path. Firstmate has its own project-level `AGENTS.md` inside `~/firstmate`; this file governs the shared WSL agent environment and must not be replaced by Firstmate's distro policy.

## Durable repository decisions

- The target is Ubuntu WSL2 with the registered distro name exactly `Ubuntu`.
- Windows Orca reaches Ubuntu only through key-authenticated SSH on `127.0.0.1:2222`.
- Repositories and worktrees belong under `/home/...`, never `/mnt/c`. Use Linux Git only.
- Firstmate owns creation, reuse, movement, and removal of project and crew worktrees under `~/firstmate/projects` through its reviewed Linux Treehouse backend.
- Windows Orca connects to WSL over SSH and may inspect or operate inside an explicitly selected Firstmate worktree, but it must not create, move, remove, or prune those worktrees.
- AGY, Pi, and Prime must never run `git worktree add`, `git worktree remove`, `git worktree prune`, Treehouse allocation, or another worktree manager. Only Firstmate's orchestrator may allocate its crew worktrees.
- Agents may operate only inside a worktree explicitly assigned by Firstmate and exposed through the Orca/SSH workflow.
- The regular Home Manager shell owns daily shell UX, Node 24, the three harness launchers, shared paths, and Nix-provided support tools.
- `nix develop .#orca-prime` is an optional Node 22/build-validation shell. It is not required to launch AGY, Pi, Prime, or Firstmate.
- Firstmate's project coordination home is `~/firstmate`; project roots are under `~/firstmate/projects`.
- Firstmate must use its reviewed Linux `tmux`/Treehouse backend for project and crew worktrees. Do not select its macOS-only `orca` backend in this WSL/Windows topology.
- Ubuntu apt/system bootstrap owns systemd, OpenSSH, sshd configuration, `build-essential`, and global `python3`.
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

- `agy`, `pi`, and `prime-agent` run directly from the regular Home Manager shell and remain the only script-installed agents.
- `gh-axi`, `lavish-axi`, `no-mistakes`, Codebase Memory, Firstmate, Treehouse, Caveman, and `i-have-adhd` are pinned Nix/Home Manager packages.
- Run only `scripts/install-home-agents.sh` and `scripts/install-prime-tools.sh` for the three user-owned agent binaries. Do not require `nix develop .#orca-prime` for installation or normal agent launch.
- Never run any harness or installer as root.
- Keep authentication, sessions, caches, logs, downloads, daemon sockets, and generated state outside this repository.
- The dotfiles repository owns policy, settings, launchers, checksums, install scripts, and documentation only.

## Prime safety

- Prime is not a sandbox; generated Python, shell commands, skills, workers, and the persistent IPython kernel execute with the Ubuntu user's permissions.
- Do not authenticate services, publish artifacts, upload traces, install software, modify GitHub, or expose a network listener without explicit approval.
- Use `gh-axi` read-only initially: list, view, search, checks, logs, and repository context only. Do not create branches, merge, approve, release, edit workflows, or mutate repository settings.
- Run Lavish only on `127.0.0.1` with `--no-open`. Never use `lavish-axi share`, hooks, plugins, public sharing, or non-loopback binding.

## Shared skills

- Caveman is available to AGY, Pi, and Prime through their client-compatible global skill roots.
- `i-have-adhd` is pinned and available to all three harnesses, but it is never activated automatically.
- Skills change presentation or workflow guidance only. They never grant permissions, suppress evidence, or change engineering scope.
- Use `/caveman ultra` for token-efficient coding-agent prompts unless full-detail output is required.
- Keep code, identifiers, API names, commands, and exact errors unchanged. Do not compress security warnings, irreversible confirmations, or ambiguous multi-step sequences.

## Optional ADHD mode

- Activate only after `/skill:i-have-adhd` or an explicit request for ADHD mode.
- `normal mode` or `stop adhd mode` disables it for the session.
- Never omit safety warnings, uncertainty, blockers, failures, required steps, or validation evidence to satisfy brevity, list limits, or time-estimate rules.

## Codebase Memory MCP - token-efficient workflow

Codebase Memory is configured as the `codebase_memory` stdio MCP server for AGY, Pi, and Prime. It uses the pinned Nix package `codebase-memory-mcp` on PATH, working directory `/home/ricardo/src`, cache `/home/ricardo/.cache/codebase-memory-mcp`, and allowed root `/home/ricardo/src`. Diagnostics remain disabled, and destructive tools remain disabled.

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

## Required validation

Before proposing a commit or pull request:

```bash
./scripts/validate.sh
```

Also parse `scripts/windows-orca-bootstrap.ps1`, run ShellCheck on shell scripts, and run target smoke checks in Ubuntu WSL. If the current environment cannot execute a required boundary, report it as unverified rather than fabricating success.

## General engineering rules

- When writing commit messages, never automatically add the agent name as a co-author.
- Never manually modify `CHANGELOG.md` files or files marked as auto-generated.
- For bug fixes, first reproduce the bug in an end-to-end setting as closely aligned with the end-user experience as possible.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection. If something clearly looks off, try to get it fixed along the way.
- Apply the same high standard to engineering excellence: fix lint failures, test failures, and test flakiness encountered during work.

## Maintaining this file

Keep only durable knowledge useful to all three harnesses. Client-specific syntax belongs in client-specific configuration and documentation. Firstmate's project-distro policy belongs in `~/firstmate/AGENTS.md`; do not duplicate its internal operational instructions here.
