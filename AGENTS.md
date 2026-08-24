# Project notes for agents

Deliberate decisions in this repository:

- The target is Ubuntu WSL2 with the registered distro name exactly `Ubuntu`.
- Windows Orca 1.4.184 reaches Ubuntu only through key-authenticated SSH on `127.0.0.1:2222`.
- Repositories and worktrees belong under `/home/...`, never `/mnt/c`. Use Linux Git only.
- Orca exclusively creates, reuses, moves, and removes coding worktrees. Prime and legacy tools do not manage Orca worktrees.
- Ubuntu apt/system bootstrap owns systemd, OpenSSH, sshd configuration, `build-essential`, and global `python3`. Do not move those pre-relay requirements into Home Manager or a project shell.
- The default Home Manager profile owns Zsh, Starship, Git, CLI tools, Neovim, ABNT2 support, and global Node 24.
- `nix develop .#orca-prime` intentionally shadows global Node 24 with Node 22.
- WezTerm, Herdr, Claude Code, and Codex remain isolated in the optional legacy profile. AGY and Pi are user-installed transitional tools in the default Home Manager profile, not Orca worktree managers.
- Do not restore permission-bypass or approval-bypass aliases to the default profile.
- Prime is not a sandbox and must never run as root. Keep `PRIME_AGENT_TELEMETRY=0`.
- `home/.prime/agent/AGENTS.md` and `settings.json` are public reviewed policy. Never add auth, tokens, sessions, provider credentials, telemetry identity, caches, or daemon state.
- The `i-have-adhd` input is presentation-only, opt-in, pinned, and limited to `skills/i-have-adhd`. Do not enable its hooks, extensions, plugins, package scripts, or repository installer.
- Lavish binds only to loopback and does not publish or share. gh-axi starts read-only.
- Never commit private keys, `authorized_keys`, credentials, installer binaries, or `.no-mistakes/` validation evidence.
- Host-mutating bootstrap execution, authentication, publication, push, and pull-request creation require explicit human approval.

## Required validation

Before proposing a commit or pull request:

```bash
./scripts/validate.sh
```

Also parse `scripts/windows-orca-bootstrap.ps1`, run ShellCheck on shell scripts, and run target smoke checks in Ubuntu WSL. If the current environment cannot execute a required boundary, report it as unverified rather than fabricating success.

## Maintaining this file

Keep only durable knowledge useful to most future agent sessions. Point to authoritative files instead of duplicating implementation details. Prefer replacing stale entries over appending new ones.
