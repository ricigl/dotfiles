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
