# dotfiles: Ubuntu WSL, Orca, and Prime

This repository is the authoritative Home Manager configuration for Ricardo's Ubuntu WSL development environment.

The default lane is:

```text
Windows 10
└── Orca 1.4.184
    └── SSH 127.0.0.1:2222
        └── Ubuntu WSL2 distro "Ubuntu"
            └── Linux repository/worktree under /home/...
                ├── Home Manager: Zsh, Starship, Git, CLI tools, Neovim, ABNT2, Node 24, AGY/Pi/Prime PATH, shared agent policy/skills/MCP, Firstmate launcher
                └── nix develop .#orca-prime: optional Node 22, Python, uv, gh, build and validation tools
```

The previous WezTerm, Herdr, Claude Code, and Codex environment remains available as the optional `legacy` Home Manager profile. Pi's authored configuration remains available there, while the default profile can install the user-owned Pi CLI through the reviewed transitional installer.

## Responsibility boundaries

| Layer | Owns |
|---|---|
| Windows and Ubuntu bootstrap | WSL resources, systemd, OpenSSH, `127.0.0.1:2222`, `build-essential`, global `python3` |
| Home Manager | Zsh, Starship, Git, user CLI tools, Neovim, ABNT2, global Node 24, `~/.local/bin` and npm PATH, AGY/Pi/Prime launchers, shared policy/skills/MCP config, Firstmate launcher and tmux |
| `.#orca-prime` | Optional Node 22, Python, uv, gh, jq, ripgrep, make, GCC, pkg-config, and build-validation environment |
| Firstmate | Linux project-fleet coordination and Treehouse-managed project/crew worktrees under `~/firstmate/projects` |
| Windows Orca | SSH client/control surface for selected WSL projects and Firstmate worktrees; no worktree lifecycle ownership |
| Prime | Coding and reasoning inside the current Firstmate-assigned worktree |

Orca's SSH relay starts before `nix develop`. Therefore Ubuntu must provide `/usr/bin/make`, `/usr/bin/g++`, and `/usr/bin/python3` globally. The matching Nix packages supplement those host prerequisites; they do not replace them.

## Fixed versions and pins

- WSL distro name: `Ubuntu`
- Orca: `1.4.184`
- Orca installer SHA-256: `7765f7f085d04b7fe662ec664825fedd81427dd586023f945182a46e0a0cf5be`
- Prime Agent: `0.8.0`
- Lavish AXI: `0.1.50`
- gh-axi: `0.1.30`
- Codebase Memory MCP: `0.10.8`
- no-mistakes: `1.57.0`
- no-mistakes Linux x86_64 SHA-256: `1145e7bd41a013013eae4baa533d241322d20d917ffef732595460ddbf385b84`
- AGY bootstrapper SHA-256: `ee1ea43ce4e9e56356c4ab6dad907ef357ae4bdfcaadb682735909fb57c9c640`
- Pi bootstrapper SHA-256: `a3a3604ee550bf72c5da7da3c3014cc361c14ab3b91b1b24f097d9022bd8de5b`
- Pi MCP adapter: `2.27.0` (`npm:pi-mcp-adapter@2.27.0`)
- Firstmate: commit `038d0f7ec6ba7238a151722931434dcf06ff37c4` from `kunchenguid/firstmate`
- Treehouse: `2.0.1`, installed through the pinned Firstmate installer
- `i-have-adhd`: commit `2ed064090711586e0c97a2fbbf15465fe8f1808b`, skill directory only

`flake.lock` pins Nix inputs and the `i-have-adhd` source. `scripts/install-prime-tools.sh` verifies the reviewed Prime installer hash and npm package integrity before installation. `scripts/install-codebase-memory.sh` verifies the pinned Codebase Memory release archive before installing the portable binary. `scripts/install-no-mistakes.sh` verifies the pinned no-mistakes release archive before installing the user-owned binary. `scripts/install-firstmate-treehouse.sh` delegates only to the pinned Firstmate Treehouse installer and verifies Treehouse `2.0.1`.

## Security model

- Repositories and worktrees live under `/home/...`, never `/mnt/c`.
- Use Linux Git only for those repositories.
- Firstmate owns project and crew worktrees through Linux Treehouse. Windows Orca accesses explicitly selected worktrees over SSH but does not create, move, remove, or prune them.
- Prime is not a sandbox and must never run as root.
- Prime telemetry is disabled in both the dev shell and `~/.prime/agent/settings.json`.
- Lavish is restricted to `127.0.0.1` and must not publish or share artifacts.
- gh-axi begins read-only.
- no-mistakes telemetry and automatic update checks are disabled by Home Manager. Its daemon, gate repositories, worktrees, logs, database, and evidence remain local mutable state.
- AGY and Pi are user-owned transitional installs. Their reviewed bootstrap scripts are pinned, but upstream release payloads remain dynamic and may self-update; auth, sessions, caches, logs, and downloads remain local and untracked.
- Firstmate is a separate user-owned checkout initialized at a reviewed commit. Its operational `data/`, `state/`, `config/`, `sessions`, caches, `projects/`, and Treehouse worktree state stay outside this repository; its own update flow is intentional mutable state.
- Codebase Memory is local-only: allowed root `/home/ricardo/src`, cache `/home/ricardo/.cache/codebase-memory-mcp`, diagnostics off, and no committed graph artifact.
- AGY, Pi, and Prime Codebase Memory MCP entries disable initial mutating/high-risk tools: `delete_project`, `manage_adr`, and `ingest_traces`.
- `i-have-adhd` is opt-in presentation policy, not an execution or permission policy.
- Private keys, authorized keys, provider credentials, sessions, caches, and runtime state are never committed.

## Clean installation

### 1. Prepare Windows and WSL

Install WSL2 and register the distribution with the exact name `Ubuntu`. Confirm from PowerShell:

```powershell
wsl.exe --list --verbose
wsl.exe --set-default Ubuntu
```

Clone this repository inside Ubuntu, not on the Windows filesystem:

```bash
mkdir -p ~/src
git clone https://github.com/ricigl/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

Run the Ubuntu host bootstrap:

```bash
./scripts/ubuntu-bootstrap.sh
```

It installs the pre-Nix packages, preserves existing `/etc/wsl.conf` sections while enabling systemd, installs a loopback-only sshd drop-in, and validates the effective SSH policy. If it exits with status 2, run this in PowerShell:

```powershell
wsl.exe --shutdown
```

Restart Ubuntu, then verify:

```bash
cd ~/.dotfiles
./scripts/ubuntu-bootstrap.sh --verify-only
```

The managed sshd policy is:

```text
Port 2222
ListenAddress 127.0.0.1
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers <current Ubuntu user>
```

### 2. Create the dedicated Windows SSH identity

From PowerShell, locate the script through WSL and apply the Windows-side configuration:

```powershell
$WslUser = (wsl.exe -d Ubuntu -- bash -lc 'printf %s "$USER"').Trim()
$Repo = "\\wsl.localhost\Ubuntu\home\$WslUser\.dotfiles"
& "$Repo\scripts\windows-orca-bootstrap.ps1" -Apply
```

This preserves existing `.wslconfig` sections while setting conservative defaults, creates `%USERPROFILE%\.ssh\orca-wsl-ed25519`, authorizes only its public key in Ubuntu, and verifies the loopback SSH connection and native build prerequisites.

To install the pinned Orca version as part of the same flow:

```powershell
& "$Repo\scripts\windows-orca-bootstrap.ps1" -Apply -InstallOrca
```

To verify without applying changes:

```powershell
& "$Repo\scripts\windows-orca-bootstrap.ps1" -VerifyOnly
```

### 3. Install Nix and activate Home Manager

Install Determinate Nix using its reviewed official installation instructions, start a new Ubuntu shell, and confirm:

```bash
nix --version
```

Then activate the default profile:

```bash
cd ~/.dotfiles
./bootstrap.sh
```

The bootstrap validates the committed lockfile, builds the activation package, creates a timestamped Home Manager backup, and activates `ricardo@wsl`.

Normal updates use:

```bash
cd ~/.dotfiles
./rebuild.sh
```

`rebuild.sh` passes a timestamped Home Manager backup suffix so existing files such as `~/.prime/agent/settings.json` are moved aside instead of being clobbered. To run the equivalent command manually, use a backup extension:

```bash
home-manager switch -b backup --flake "$HOME/.dotfiles#$(whoami)@wsl"
```

### 4. Use the optional Node 22 validation shell

The regular Home Manager shell is the daily runtime for AGY, Pi, Prime, and Firstmate. Keep the development shell only for deterministic Node 22/build validation:

```bash
cd ~/.dotfiles
nix develop .#orca-prime
```

Inside that optional shell:

```bash
node --version
python3 --version
uv --version
gh --version
```

Expected Node major version inside the optional shell: `v22`.

Return to a fresh regular shell before running the user-owned installers below. They do not require `nix develop`.

### 5. Install the reviewed user-owned tools from the regular shell

Install AGY and Pi first:

```bash
cd ~/.dotfiles
./scripts/install-home-agents.sh
agy --version
pi --version
pi list | grep pi-mcp-adapter
```

Install Prime, Lavish, and gh-axi from the regular shell:

```bash
./scripts/install-prime-tools.sh
prime-agent --version
lavish-axi --version
gh-axi --version
```

Install the pinned Codebase Memory MCP server:

```bash
./scripts/install-codebase-memory.sh
codebase-memory-mcp --version
```

Install the pinned no-mistakes CLI without starting its daemon or changing Git remotes:

```bash
./scripts/install-no-mistakes.sh
no-mistakes --version
no-mistakes doctor
```

The no-mistakes installer uses a checksum-verified Linux x86_64 release, installs the real binary under `~/.no-mistakes/bin`, and links it from `~/.local/bin`. It does not run `no-mistakes init`, add a `no-mistakes` Git remote, start a daemon, or start a validation gate.

The repository policy is in `.no-mistakes.yaml`. It selects targeted shell and Prime maintenance checks, keeps evidence outside Git, and leaves `allow_repo_commands` disabled. Review the configuration and the trusted-default-branch behavior before manually initializing this repository:

```bash
no-mistakes init
git remote -v
no-mistakes doctor
```

Only after that review should you use `git push no-mistakes <branch>` or `/no-mistakes` from a supported coding agent. The no-mistakes remote forwards changes only after its configured pipeline passes.

These installers use user-owned locations. They do not require root and must never be run with `sudo`.

### Shared AGY, Pi, and Prime policy, skills, and Codebase Memory

The repository root `AGENTS.md` is the single tracked shared policy for AGY, Pi, and Prime. Home Manager exposes that same source to Pi as `~/.pi/agent/AGENTS.md`, to AGY as `~/.gemini/GEMINI.md`, and to Prime as `~/.prime/agent/AGENTS.md`. Prime's safety, worktree, telemetry, and engineering rules are merged into the common file.

The reviewed Caveman and pinned `i-have-adhd` skills are exposed to all three harnesses through their supported skill roots. Use `/caveman ultra` for token-efficient coding-agent prompts when full-detail output is not required. `i-have-adhd` remains opt-in.

Codebase Memory is available to all three harnesses after the pinned binary is installed:

```text
Pi shared MCP config: ~/.config/mcp/mcp.json
AGY global MCP config: ~/.gemini/config/mcp_config.json
AGY compatibility MCP config: ~/.gemini/antigravity-cli/mcp_config.json
Prime MCP config: ~/.prime/agent/settings.json
Server: /home/ricardo/.local/bin/codebase-memory-mcp
Allowed root: /home/ricardo/src
Cache: /home/ricardo/.cache/codebase-memory-mcp
```

Pi uses the pinned `pi-mcp-adapter@2.27.0`; AGY uses native stdio MCP support; Prime uses its generic MCP configuration. All configurations keep diagnostics off and disable `delete_project`, `manage_adr`, and `ingest_traces`. For non-trivial work, follow the graph-first workflow in the shared `AGENTS.md`: check index status, get a bounded architecture overview, search narrowly, trace relevant paths, read exact symbols, verify source, and run blast-radius checks after edits.

### Firstmate project crew

Firstmate is an agent distro rather than a conventional CLI or MCP server. Its cloned repository supplies the project-level `AGENTS.md`, skills, runtime scripts, and private fleet-state conventions. The dotfiles profile therefore keeps Firstmate in a separate user-owned checkout instead of copying its policy over the shared AGY/Pi policy.

Install the reviewed commit after rebuilding Home Manager and opening a new shell:

```bash
cd ~/.dotfiles
./scripts/install-firstmate.sh
./scripts/install-firstmate.sh --check
./scripts/install-firstmate-treehouse.sh
./scripts/install-firstmate-treehouse.sh --check
```

The checkout is created at `~/firstmate` by default, with `~/firstmate/projects` created for project clones and Treehouse-managed crew worktrees. Its `data/`, `state/`, `config/`, sessions, caches, and projects remain outside this repository. The installer refuses root, symlinked or dirty existing checkouts, unexpected origins, and silent resets of an already-updated checkout. It installs the pinned commit as the initial baseline; Firstmate's own `/updatefirstmate` flow can intentionally fast-forward the checkout later.

Install the pinned Linux Treehouse worktree provider separately:

```bash
./scripts/install-firstmate-treehouse.sh
./scripts/install-firstmate-treehouse.sh --check
treehouse --version
```

The default Home Manager profile provides a `firstmate` launcher. It verifies the checkout shape, requires `tmux` and Treehouse, enters the Firstmate root, sets `FM_ROOT_OVERRIDE`, `FM_HOME`, and `FM_BACKEND=tmux`, and starts the already-installed Pi harness:

```bash
firstmate
```

Firstmate owns project and crew worktrees through Linux Treehouse. Windows Orca connects to WSL over SSH and may access an explicitly selected Firstmate worktree, but it does not create, move, remove, or prune worktrees. Do not select Firstmate's macOS-only `orca` backend in this WSL/Windows topology.

The default Home Manager profile also provides a direct `prime` launcher. It runs the user-installed Prime Agent from the regular Node 24 shell:

```bash
prime
prime --help
```

The launcher preserves the arguments, sets a stable runtime `TMPDIR` parent for Prime's daemon socket, and does not enter `nix develop`. The optional `.#orca-prime` shell remains available for Node 22/build validation only.

## Prime maintenance

The default Home Manager profile provides a safe `prime-maintenance` utility for inspecting Prime workers and saved sessions without printing conversation contents:

```bash
prime-maintenance
prime-maintenance list
prime-maintenance list-agents
prime-maintenance list-sessions
```

Prime worker operations use Prime's supported lifecycle commands:

```bash
prime-maintenance stop-agent <agent-id>
prime-maintenance stop-all-agents
```

Saved sessions are JSONL files and can contain private prompts, tool calls, and responses. The utility lists only metadata such as the session ID, safe display name, working directory, lifecycle state, path, and modification time:

```bash
prime-maintenance delete-session <session-id>
prime-maintenance delete-all-sessions
```

Session deletion moves files to the desktop trash when `trash` or `gio` is available. Permanent deletion requires the explicit `--permanent` flag. Active sessions are refused until their owning agent is stopped. All destructive actions require confirmation unless `--yes` is supplied. The combined emergency cleanup command requires the phrase `DELETE ALL PRIME STATE`:

```bash
prime-maintenance clean-all
```

For the normal workflow where named sessions are active work, use the narrower cleanup command:

```bash
prime-maintenance clean-unnamed
```

It requires the phrase `CLEAN UNNAMED PRIME STATE`, stops all Prime agents through Prime's lifecycle command, re-reads session metadata, and moves only sessions with an empty name to trash. Named sessions are preserved. Active unnamed sessions are refused rather than deleted. Add `--permanent` only when permanent deletion is explicitly intended; `--yes` skips the confirmation phrase for this explicit command.

Use `--session-dir` with disposable fixtures or a separately managed Prime session directory. Never commit the session directory or its contents.

Codebase Memory is configured as a native stdio MCP server in `home/.prime/agent/settings.json`:

```text
command: /home/ricardo/.local/bin/codebase-memory-mcp
cwd: /home/ricardo/src
```

Codebase Memory `0.10.8` uses the approved `auto_index=true` and `auto_watch=true` settings; this stdio configuration starts neither the optional UI nor any shared graph artifact. Use Prime's MCP tools to index/query repositories under `/home/ricardo/src`; do not commit `.codebase-memory` directories, exported graph artifacts, or cache contents.

To inspect the connection from the shell:

```bash
prime-agent mcp list
```

Inside a Prime session, the generic MCP API is pre-imported:

```python
import mcp
await mcp.list_tools("codebase_memory")
await mcp.call_tool(
    "codebase_memory",
    "index_repository",
    {"repo_path": "/home/ricardo/src/example", "mode": "fast", "persistence": False},
)
```

Use `get_architecture`, `search_graph`, `query_graph`, `trace_path`, and `get_code_snippet` before broad file reads. Keep `persistence` false unless a separately reviewed shared graph artifact is desired.

### 5. Register Ubuntu in Orca

In Orca 1.4.184, add an SSH host with:

```text
Name: Ubuntu WSL2
Host: 127.0.0.1
Port: 2222
User: <your Ubuntu username>
Private key: %USERPROFILE%\.ssh\orca-wsl-ed25519
```

Add projects by browsing to a Linux path such as:

```text
/home/<user>/src/<repository>
```

Do not add the repository through Orca's Local Windows host. Let Orca create and manage its own worktrees.

### 6. Start Prime in an Orca terminal

In an Orca Empty Terminal attached to the assigned worktree:

```bash
prime --tools ipython
```

Initial Prime operating limits are defined in the shared `AGENTS.md` and exposed at `~/.prime/agent/AGENTS.md`: one root agent, no autonomous schedules or recursive write-heavy agents, gh-axi read-only, and no publication or external side effects without approval.

ADHD presentation mode is opt-in:

```text
/skill:i-have-adhd
```

Use `normal mode` or `stop adhd mode` to disable it for the session.

## Validation

Static and Nix validation:

```bash
cd ~/.dotfiles
./scripts/validate.sh
```

Runtime checks outside the dev shell confirm global Node 24:

```bash
./tests/smoke-orca-prime.sh
```

Runtime checks inside the dev shell confirm Node 22 and Prime environment policy:

```bash
nix develop .#orca-prime --command ./tests/smoke-orca-prime.sh
```

Windows and Ubuntu host checks:

```powershell
& "$Repo\scripts\windows-orca-bootstrap.ps1" -VerifyOnly
```

```bash
./scripts/ubuntu-bootstrap.sh --verify-only
```

## Legacy fallback

Activate the previous WezTerm, Herdr, Pi, Claude Code, and Codex profile only when needed:

```bash
DOTFILES_PROFILE=legacy ./rebuild.sh
```

Return to the conservative default profile with:

```bash
./rebuild.sh
```

The legacy profile retains the old tools but does not restore the removed high-agency permission-bypass aliases.

## Rollback

### Home Manager

List generations:

```bash
home-manager generations
```

Run the `activate` program from the prior generation path shown by that command.

### Git branch

The migration is developed on `feat/orca-prime-home-manager`. The original `main` branch remains the baseline until a reviewed pull request is merged.

### Ubuntu SSH

The managed file is:

```text
/etc/ssh/sshd_config.d/99-orca-wsl.conf
```

Before changing or removing it, keep an external shell open. Validate every edit with `sudo sshd -t`, then restart with `sudo systemctl restart ssh`.

### Codebase Memory

Remove the user-installed MCP binary and cache:

```bash
rm -f ~/.local/bin/codebase-memory-mcp
rm -rf ~/.cache/codebase-memory-mcp
```

Then remove or disable `mcpServers.codebase_memory` in `home/.prime/agent/settings.json` and rebuild Home Manager.

## Repository map

- `flake.nix`: Home Manager profiles, optional Node 22/build-validation shell, and Home Manager app.
- `modules/home-base.nix`: default user packages, shell/editor configuration, Node 24, npm PATH, and direct Prime launcher.
- `modules/home-common-agents.nix`: shared AGENTS.md, skills, and MCP links for AGY, Pi, and Prime.
- `modules/home-orca-prime.nix`: reviewed Prime settings and Codebase Memory environment only.
- `modules/home-firstmate.nix`: Firstmate launcher, explicit Linux backend guard, and tmux runtime dependency.
- `modules/home-legacy-agents.nix`: WezTerm, Herdr, Pi, Claude Code, and Codex fallback.
- `scripts/ubuntu-bootstrap.sh`: Ubuntu system and sshd bootstrap.
- `scripts/windows-orca-bootstrap.ps1`: Windows resources, dedicated SSH key, optional Orca installer.
- `scripts/install-prime-tools.sh`: pinned transitional Prime/Lavish/gh-axi installation.
- `scripts/install-codebase-memory.sh`: pinned Codebase Memory MCP portable binary installation.
- `scripts/install-no-mistakes.sh`: pinned no-mistakes CLI installation with checksum verification.
- `scripts/install-home-agents.sh`: checksum-verified AGY and Pi bootstrap installation for the regular Home Manager shell.
- `scripts/install-firstmate.sh`: pinned, user-owned Firstmate checkout installation and verification.
- `scripts/install-firstmate-treehouse.sh`: pinned Firstmate Treehouse prerequisite installation and verification.
- `scripts/prime-maintenance.py`: safe Prime worker and session inspection/cleanup utility.
- `scripts/validate.sh`: static, secret, flake, profile, and dev-shell validation.
- `.no-mistakes.yaml`: targeted no-mistakes gate policy with local-only evidence.
- `tests/smoke-orca-prime.sh`: target-runtime acceptance checks, including Firstmate checkout verification.
- `tests/test-firstmate-install.sh`: disposable Firstmate installer checks.
- `tests/test-prime-maintenance.sh`: disposable session metadata and deletion-safety tests.
- `home/`: repository-authored configuration linked by Home Manager.

## Notes

- The first Neovim launch bootstraps `lazy.nvim` from GitHub.
- Prime auth, sessions, daemon state, provider credentials, telemetry identity, Codebase Memory indexes, and caches remain local mutable state.
- Home Manager owns the exact reviewed shared policy and Prime settings files, not the entire `~/.prime/agent` directory.

## License

MIT No Attribution. See `LICENSE`.
