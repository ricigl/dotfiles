# dotfiles: Ubuntu WSL, Herdr, and Prime

This repository is the authoritative Home Manager configuration for Ricardo's Ubuntu WSL development environment.

The default lane is:

```text
Windows 10
└── Herdr 0.8.2 thin client
    └── SSH 127.0.0.1:2222
        └── Ubuntu WSL2 distro "Ubuntu"
            └── Linux repository/worktree under /home/...
                ├── Home Manager: Zsh, Starship, Git, CLI tools, Neovim, ABNT2, Node 24, AGY/Pi/Prime PATH, shared agent policy/skills/MCP, Firstmate launcher
                └── nix develop .#orca-prime: optional Node 22, Python, uv, gh, build and validation tools
```

The previous WezTerm, Claude Code, and Codex environment remains available as the optional `legacy` Home Manager profile. Herdr is now part of the regular Home Manager profile, and Pi's authored configuration remains available in the legacy profile while the default profile can install the user-owned Pi CLI through the reviewed transitional installer.

## Responsibility boundaries

| Layer | Owns |
|---|---|
| Windows and Ubuntu bootstrap | WSL resources, systemd, OpenSSH, `127.0.0.1:2222`, `build-essential`, global `python3`, Windows WezTerm terminal emulator, WinGet/App Installer |
| Home Manager | Zsh, Starship, Git, user CLI tools, Neovim, ABNT2, global Node 24, Google Chrome (`pkgs.google-chrome`), Nix-packaged support tools (`herdr`, `codebase-memory-mcp`, `no-mistakes`, `lavish-axi`, `gh-axi`, `quota-axi`, `tasks-axi`, `chrome-devtools-axi`, `pi-openai-server-compaction`), `~/.local/bin` and npm PATH, AGY/Pi/Prime launchers, shared policy/skills/MCP config, Firstmate and Treehouse |
| `.#orca-prime` | Optional Node 22, Python, uv, gh, jq, ripgrep, make, GCC, pkg-config, and build-validation environment |
| Firstmate | Linux project-fleet coordination and Treehouse-managed project/crew worktrees under `~/firstmate/projects` |
| Windows Herdr | SSH thin client for selected WSL projects and Firstmate worktrees; no worktree lifecycle ownership |
| Prime | Coding and reasoning inside the current Firstmate-assigned worktree |

Herdr's remote SSH attach starts before `nix develop`. Therefore Ubuntu must provide `/usr/bin/make`, `/usr/bin/g++`, and `/usr/bin/python3` globally. The matching Nix packages supplement those host prerequisites; they do not replace them.

## Fixed versions and pins

- WSL distro name: `Ubuntu`
- Herdr: `0.8.2`
- Herdr Windows installer script SHA-256: `3415ea0bc562cad003afcc70ac9916b81cde043c4c26087f05255ae7807d1ba7`
- Windows WezTerm WinGet package: `wez.wezterm`
- Prime Agent: `0.8.0`
- Lavish AXI: `0.1.50`
- gh-axi: `0.1.30`
- quota-axi: `0.1.32`
- tasks-axi: `0.2.5`
- chrome-devtools-axi: `0.1.31`
- Google Chrome: Nix package (`pkgs.google-chrome`)
- pi-openai-server-compaction: commit `8a3de2f3b0c178fdd6f73f2f94172dfc3943e466`
- Codebase Memory MCP: `0.10.8`
- no-mistakes: `1.57.0`
- no-mistakes Linux x86_64 SHA-256: `1145e7bd41a013013eae4baa533d241322d20d917ffef732595460ddbf385b84`
- AGY bootstrapper SHA-256: `ee1ea43ce4e9e56356c4ab6dad907ef357ae4bdfcaadb682735909fb57c9c640`
- Pi bootstrapper SHA-256: `a3a3604ee550bf72c5da7da3c3014cc361c14ab3b91b1b24f097d9022bd8de5b`
- Pi MCP adapter: `2.27.0` (`npm:pi-mcp-adapter@2.27.0`)
- Firstmate: commit `038d0f7ec6ba7238a151722931434dcf06ff37c4` from `kunchenguid/firstmate`
- Treehouse: `2.0.1`, Nix package
- `i-have-adhd`: commit `2ed064090711586e0c97a2fbbf15465fe8f1808b`, skill directory only

`flake.lock` pins Nix inputs and the `i-have-adhd` source. The fixed-output packages in `packages/default.nix` pin release hashes and npm lockfile integrity values. Google Chrome and the four support tools (`quota-axi`, `tasks-axi`, `chrome-devtools-axi`, `pi-openai-server-compaction`) are Nix/Home Manager managed. Only the AGY/Pi and Prime Agent binaries remain script-installed.

## Security model

- Repositories and worktrees live under `/home/...`, never `/mnt/c`.
- Use Linux Git only for those repositories.
- Firstmate owns project and crew worktrees through Linux Treehouse. Windows Herdr accesses explicitly selected worktrees over SSH but does not create, move, remove, or prune them.
- Prime is not a sandbox and must never run as root.
- Prime telemetry is disabled in both the dev shell and `~/.prime/agent/settings.json`.
- Lavish is restricted to `127.0.0.1` and must not publish or share artifacts.
- gh-axi begins read-only.
- Chrome and chrome-devtools-axi profile directory `~/.local/share/chrome-devtools-axi/dev-profile`, browser sessions, cookies, and local data are local mutable state created with mode 0700 during Home Manager activation and stay outside Git.
- no-mistakes telemetry and automatic update checks are disabled by Home Manager. Its daemon, gate repositories, worktrees, logs, database, and evidence remain local mutable state.
- AGY and Pi are user-owned transitional installs. Their reviewed bootstrap scripts are pinned, but upstream release payloads remain dynamic and may self-update; auth, sessions, caches, logs, and downloads remain local and untracked. Herdr is supplied by the pinned Home Manager package on Linux; its Windows client uses the reviewed official stable installer.
- Firstmate is packaged from a reviewed commit; its operational `data/`, `state/`, `config/`, `sessions`, caches, `projects/`, and Treehouse worktree state stay outside this repository.
- Codebase Memory is local-only: allowed root `/home/ricardo`, cache `/home/ricardo/.cache/codebase-memory-mcp`, diagnostics off, and no committed graph artifact. Index only explicit project directories such as `/home/ricardo/src/<project>` or `/home/ricardo/firstmate/projects/<project>`; never index `/home/ricardo` itself or credential/config directories.
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

### 2. Prepare Windows client key, authorize in Ubuntu, and bootstrap Windows Herdr

Bootstrap SSH authentication and Windows tools in three explicit steps:

#### Step 1: Generate or prepare the Windows client SSH key

From Windows PowerShell, run the Windows key helper script:

```powershell
$WslUser = (wsl.exe -d Ubuntu -- id -un).Trim()
$Repo = "\\wsl.localhost\Ubuntu\home\$WslUser\.dotfiles"
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "$Repo\scripts\windows-herdr-key-bootstrap.ps1"
```

This creates or reuses `%USERPROFILE%\.ssh\orca-wsl-ed25519`, derives the public key using `ssh-keygen -y -f`, and writes a clean LF-only UTF-8 public key to `%TEMP%\orca-wsl-manual.pub` without BOM or trailing carriage returns. It also prints the public-key fingerprint; do not paste the key contents.

#### Step 2: Authorize the key inside Ubuntu WSL

From the Ubuntu WSL terminal, authorize the exported Windows public key by passing its WSL mount path:

```bash
cd ~/.dotfiles
./scripts/ubuntu-authorize-windows-key.sh /mnt/c/Users/Ricardo/AppData/Local/Temp/orca-wsl-manual.pub
```

The explicit Ubuntu step is intentional: separating key export from authorization avoids fragile cross-boundary scripting, validates key syntax with `ssh-keygen -lf -`, resolves the user home safely with `getent passwd`, ensures secure permissions (0700 `~/.ssh` and 0600 `~/.ssh/authorized_keys`), and appends the key only if absent without clobbering existing authorized keys or exposing private key material. Compare the fingerprint printed by this step with the fingerprint printed in Step 1; they must match.

> [!WARNING]
> The bootstrap verifies loopback SSH with `StrictHostKeyChecking=accept-new`. Accepting a changed host key is safe only after an intentional WSL reinstall. If an unexpected host key change occurs, investigate before accepting it.

#### Step 3: Apply Windows configuration, install Herdr / WezTerm, and verify

From Windows PowerShell, apply the `.wslconfig` resource settings, install Herdr and WezTerm, and verify the SSH relay connection:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "$Repo\scripts\windows-herdr-bootstrap.ps1" `
  -Apply -InstallHerdr -InstallWezTerm -ConfigureHerdrAlias -ConfigureWezTerm -InstallHackNerdFont
```

This preserves existing `.wslconfig` sections while setting conservative defaults (8GB memory, 6 processors, 4GB swap, localhost forwarding), installs the reviewed stable Herdr client from `https://herdr.dev/install.ps1` (verified against SHA-256 `3415ea0bc562cad003afcc70ac9916b81cde043c4c26087f05255ae7807d1ba7`), installs WezTerm via WinGet using exact package ID `wez.wezterm`, configures an idempotent PowerShell-profile `herdr` function, creates a shell-independent command shim in `%LOCALAPPDATA%\Programs\Herdr\remote-bin\herdr.cmd` and adds it to the current user PATH, copies the tracked WezTerm configuration to `%USERPROFILE%\.config\wezterm\wezterm.lua` with a timestamped backup of differing existing content, and verifies the loopback SSH connection, native build prerequisites, WinGet availability, and WezTerm installation. After opening a new PowerShell, cmd.exe, or WezTerm window, bare `herdr` connects to Ubuntu automatically; additional arguments such as `herdr --session agents` are forwarded.

The tracked WezTerm configuration is based on [Kun Cheng's example](https://github.com/kunchenguid/dotfiles/blob/main/home/.config/wezterm/wezterm.lua). It keeps the native Windows title bar and resize borders with `window_decorations = "TITLE | RESIZE"`, so the window remains draggable. `-InstallHackNerdFont` installs Hack Nerd Font v3.5.1 from the official Nerd Fonts release into the current user's Windows font directory after verifying SHA-256 `fa24da7de7cefe7766614d27762570b20453c852fc1d5b657111666df9a5e449`.

When `-ConfigureHerdrAlias` is used, the bootstrap creates the marked `wsl-herdr` entry in `%USERPROFILE%\.ssh\config`, selecting the dedicated `orca-wsl-ed25519` key and a stable `%USERPROFILE%\.ssh\orca-wsl-known-hosts` file. It installs a dedicated command shim at `%LOCALAPPDATA%\Programs\Herdr\remote-bin\herdr.cmd` (which invokes the installed `herdr.exe --remote wsl-herdr %*` without recursing), adds `%LOCALAPPDATA%\Programs\Herdr\remote-bin` to the current user PATH idempotently without touching machine-wide PATH, and writes the marked PowerShell profile function. Both cmd.exe (such as default WezTerm sessions) and PowerShell sessions use this target, so bare `herdr` does not depend on default SSH key discovery or fall back to Windows-local sessions.

#### Troubleshooting a crates.io HTTP 403

If `./bootstrap.sh` reports a 403 for `https://crates.io/api/v1/crates/.../download` while building Herdr, the checkout is using an outdated nested nixpkgs lock. Pull the current branch and retry; Herdr is deliberately locked to the repository's root nixpkgs input, whose cargo importer uses the static crates.io CDN with the same Cargo checksums:

```bash
cd ~/.dotfiles
git pull --ff-only origin herdr-agents-nix
./bootstrap.sh
```

Do not disable Nix hashes or replace the locked Herdr dependency with an unpinned source. If the error still names the API endpoint after pulling, verify the checkout with `git log -1 --oneline` and `git status --short --branch` before changing the lockfile.

#### WezTerm and WinGet on Windows

WezTerm is the Windows terminal emulator prerequisite for this environment. It is installed via WinGet with:

```powershell
winget install --exact --id wez.wezterm --source winget --accept-source-agreements --accept-package-agreements
```

Official references:
- WezTerm installation guide: https://wezterm.org/install/windows.html#installing-on-windows
- Microsoft Learn WinGet documentation: https://learn.microsoft.com/windows/package-manager/winget/
- Microsoft Store App Installer: https://apps.microsoft.com/detail/9nblggh4nns1 (or https://aka.ms/getwinget)

WinGet (`winget.exe`) is delivered through Windows App Installer and may require first-login registration. If WinGet is absent but App Installer is installed, register it using:

```powershell
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
```

To verify without applying changes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "$Repo\scripts\windows-herdr-bootstrap.ps1" `
  -VerifyOnly
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

After the first activation, start a fresh regular shell so Home Manager's PATH and session variables are loaded before installing agents or running smoke tests:

```bash
exec zsh -l
```

The rebuild wrapper also relocates stale Home Manager skill backups out of agent skill discovery roots into `~/.local/state/orca-prime/skill-backups/` without deleting them.

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

### 5. Install the three user-owned agent binaries from the regular shell

Herdr is installed by the regular Home Manager profile. Verify it alongside AGY and Pi:

```bash
cd ~/.dotfiles
herdr --version
./scripts/install-home-agents.sh
agy --version
pi --version
pi list | grep pi-mcp-adapter
```

The regular Home Manager shell defines the interactive alias `agy` as `command agy --dangerously-skip-permissions`. After activation, start a fresh login shell with `exec zsh -l`; then `agy ...` automatically includes the flag. `command agy ...` bypasses the alias when needed.

The upstream Linux command is `curl -fsSL https://herdr.dev/install.sh | sh`; this repository intentionally uses the locked Home Manager package instead, so the WSL server is reproducible and matches the pinned `0.8.2` Windows client.

Install Prime from the regular shell. It is the only support component still installed by a reviewed script:

```bash
./scripts/install-prime-tools.sh
prime-agent --version
```

Codebase Memory, no-mistakes, Lavish, gh-axi, quota-axi, tasks-axi, chrome-devtools-axi, Google Chrome, Firstmate, Treehouse, Caveman, and `i-have-adhd` are installed by the locked Nix/Home Manager profile during `./rebuild.sh`. Verify them directly:

```bash
codebase-memory-mcp --version
no-mistakes --version
lavish-axi --version
gh-axi --version
quota-axi --version
tasks-axi --version
chrome-devtools-axi --help
command -v google-chrome-stable
printf '%s\n' "$CHROME_DEVTOOLS_AXI_USER_DATA_DIR" "$CHROME_DEVTOOLS_AXI_HEADED"
treehouse --version
command -v fm-session-start.sh
```

The Nix packages use fixed release hashes or committed lockfile integrity values. Google Chrome is installed through Home Manager (`pkgs.google-chrome`). The `chrome-devtools-axi` profile directory (`~/.local/share/chrome-devtools-axi/dev-profile`) and browser cookies/sessions remain local mutable runtime state outside the repository. Automated checks verify configuration, derivations, environment exports, and directory permissions; they do not execute browser runtime logins or mutating actions.

The repository policy is in `.no-mistakes.yaml`. Review the configuration and trusted-default-branch behavior before manually initializing this repository:

```bash
no-mistakes doctor
no-mistakes init
git remote -v
```

Only after that review should you use `git push no-mistakes <branch>` or `/no-mistakes` from a supported coding agent. These tools use user-owned locations and must never be run with `sudo`.

### Shared AGY, Pi, and Prime policy, skills, and Codebase Memory

The repository root `AGENTS.md` is the single tracked shared policy for AGY, Pi, and Prime. Home Manager exposes that same source to Pi as `~/.pi/agent/AGENTS.md`, to AGY as `~/.gemini/GEMINI.md`, and to Prime as `~/.prime/agent/AGENTS.md`. Prime's safety, worktree, telemetry, and engineering rules are merged into the common file.

The reviewed Caveman, pinned `no-mistakes`, `lavish`, `gh-axi`, `quota-axi`, `tasks-axi`, `chrome-devtools-axi`, and pinned `i-have-adhd` skills are exposed to all three harnesses through their supported skill roots (`~/.agents/skills`, `~/.gemini/antigravity-cli/skills`, and `~/.prime/agent/skills`). Use `/caveman ultra` for token-efficient coding-agent prompts when full-detail output is not required. Use `/no-mistakes` to drive the local validation gate. `i-have-adhd` remains opt-in.

Pi loads its local extension `pi-openai-server-compaction` directly from `~/.pi/agent/extensions/pi-openai-server-compaction`, packaged by Nix from the pinned commit with locked dependencies.

Codebase Memory is available to all three harnesses after the pinned binary is installed:

```text
Pi shared MCP config: ~/.config/mcp/mcp.json
AGY global MCP config: ~/.gemini/config/mcp_config.json
AGY compatibility MCP config: ~/.gemini/antigravity-cli/mcp_config.json
Prime MCP config: ~/.prime/agent/settings.json
Server: codebase-memory-mcp (Nix package on PATH)
Allowed root: /home/ricardo
Cache: /home/ricardo/.cache/codebase-memory-mcp
```

Pi uses the pinned `pi-mcp-adapter@2.27.0`; AGY uses native stdio MCP support; Prime uses its generic MCP configuration. All configurations keep diagnostics off and disable `delete_project`, `manage_adr`, and `ingest_traces`. For non-trivial work, follow the graph-first workflow in the shared `AGENTS.md`: check index status, get a bounded architecture overview, search narrowly, trace relevant paths, read exact symbols, verify source, and run blast-radius checks after edits.

### Firstmate project crew

Firstmate is packaged from the pinned upstream commit and exposed through Home Manager. Its mutable root remains separate from the Nix store:

```bash
firstmate --help
command -v fm-session-start.sh
treehouse --version
test -d ~/firstmate/projects || mkdir -p ~/firstmate/projects
```

The `firstmate` launcher creates `~/firstmate/projects` and copies the packaged project-level `AGENTS.md` into `~/firstmate` on first use. Its `data/`, `state/`, `config/`, sessions, caches, and projects remain outside this repository. Nix does not create project clones or start autonomous loops.

The default Home Manager profile provides the `firstmate` launcher. It requires `tmux`, Treehouse, and the script-installed Pi harness, enters the Firstmate root, sets `FM_ROOT_OVERRIDE`, `FM_HOME`, and `FM_BACKEND=tmux`, and starts Pi:

```bash
firstmate
```

Firstmate owns project and crew worktrees through Linux Treehouse. Windows Herdr connects to WSL over SSH and may access an explicitly selected Firstmate worktree, but it does not create, move, remove, or prune worktrees. Do not select Firstmate's macOS-only `orca` backend in this WSL/Windows topology.

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
command: codebase-memory-mcp
cwd: /home/ricardo/src
```

Codebase Memory `0.10.8` uses the approved `auto_index=true` and `auto_watch=true` settings; this stdio configuration starts neither the optional UI nor any shared graph artifact. Use Prime's MCP tools to index/query explicit repositories under `/home/ricardo/src` or `/home/ricardo/firstmate/projects`; do not index `/home/ricardo` itself, credential/config directories, or commit `.codebase-memory` directories, exported graph artifacts, or cache contents.

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

### 5. Connect the Windows Herdr thin client

Herdr uses normal OpenSSH authentication for remote attach. Use the existing dedicated key:

```text
Name: Ubuntu WSL2
Host: 127.0.0.1
Port: 2222
User: <your Ubuntu username>
Private key: %USERPROFILE%\.ssh\orca-wsl-ed25519
```

After `-ConfigureHerdrAlias`, running bare `herdr` from either PowerShell or cmd.exe (including default WezTerm windows) connects through the dedicated SSH target:

```cmd
herdr
```

The command shim (`%LOCALAPPDATA%\Programs\Herdr\remote-bin\herdr.cmd`) and the PowerShell profile function both invoke `herdr.exe --remote wsl-herdr`, preserving additional arguments such as `herdr --session agents` without recursing. To bypass the alias and invoke the binary directly, use `herdr.exe --remote wsl-herdr`. Do not use the raw `ssh://user@127.0.0.1:2222` form unless that host has its own matching `IdentityFile` entry in the OpenSSH config.

For repeat use, configure an SSH alias such as `wsl-herdr` and attach with `herdr --remote wsl-herdr`. Add projects by selecting explicit Linux paths such as `/home/<user>/src/<repository>` or `/home/<user>/firstmate/projects/<project>`.

### 6. Start Prime from a Herdr pane

In a Herdr pane attached to the assigned worktree:

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
./tests/smoke-herdr-agents.sh
```

Runtime checks inside the dev shell confirm Node 22 and Prime environment policy:

```bash
nix develop .#orca-prime --command ./tests/smoke-herdr-agents.sh
```

Windows and Ubuntu host checks:

```powershell
& "$Repo\scripts\windows-herdr-bootstrap.ps1" -VerifyOnly
```

```bash
./scripts/ubuntu-bootstrap.sh --verify-only
```

## Legacy fallback

Activate the previous WezTerm, Pi, Claude Code, and Codex profile only when needed:

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

The migration is developed on `herdr-agents-nix`, based on `orca-agents-nix`. The original `main` branch remains the baseline until a reviewed pull request is merged.

### Ubuntu SSH

The managed file is:

```text
/etc/ssh/sshd_config.d/99-orca-wsl.conf
```

Before changing or removing it, keep an external shell open. Validate every edit with `sudo sshd -t`, then restart with `sudo systemctl restart ssh`.

### Codebase Memory

Codebase Memory is Nix-managed. Remove it from `home.packages` and the three MCP configuration files, then rebuild Home Manager. Preserve or remove its mutable cache separately only after reviewing its contents:

```bash
rm -rf ~/.cache/codebase-memory-mcp
```

## Repository map

- `flake.nix`: Home Manager profiles, optional Node 22/build-validation shell, and Home Manager app.
- `modules/home-base.nix`: default user packages, Google Chrome, shell/editor configuration, Node 24, npm PATH, Chrome devtools profile activation, Herdr, and direct Prime launcher.
- `modules/home-common-agents.nix`: shared AGENTS.md, skills, and MCP links for AGY, Pi, and Prime.
- `modules/home-orca-prime.nix`: reviewed Prime settings and Codebase Memory environment only.
- `modules/home-firstmate.nix`: Firstmate launcher, explicit Linux backend guard, and tmux runtime dependency.
- `modules/home-legacy-agents.nix`: WezTerm, Pi, Claude Code, and Codex fallback additions.
- `scripts/ubuntu-bootstrap.sh`: Ubuntu system and sshd bootstrap.
- `scripts/ubuntu-authorize-windows-key.sh`: authorizes the Windows client public key in Ubuntu with permission and fingerprint checks.
- `scripts/windows-herdr-key-bootstrap.ps1`: Windows client SSH key generation and export helper.
- `scripts/windows-herdr-bootstrap.ps1`: Windows Herdr installer, WezTerm installer via WinGet, WSL resources, and SSH verification.
- `scripts/install-prime-tools.sh`: pinned Prime Agent installation; this is the only support installer remaining.
- `scripts/install-home-agents.sh`: checksum-verified AGY and Pi bootstrap installation for the regular Home Manager shell.
- `packages/default.nix`: fixed-output packages for Codebase Memory, no-mistakes, Firstmate, Treehouse, skills, Lavish, gh-axi, quota-axi, tasks-axi, chrome-devtools-axi, and pi-openai-server-compaction.
- `scripts/prime-maintenance.py`: safe Prime worker and session inspection/cleanup utility.
- `scripts/validate.sh`: static, secret, flake, profile, and dev-shell validation.
- `.no-mistakes.yaml`: targeted no-mistakes gate policy with local-only evidence.
- `tests/smoke-herdr-agents.sh`: target-runtime acceptance checks for the Herdr/Nix-managed support environment.
- `tests/test-prime-maintenance.sh`: disposable session metadata and deletion-safety tests.
- `tests/test-windows-herdr-shim.sh`: contract tests for the Windows Herdr command shim and PATH handling.
- `home/`: repository-authored configuration linked by Home Manager.

## Notes

- The first Neovim launch bootstraps `lazy.nvim` from GitHub.
- Prime auth, sessions, daemon state, provider credentials, telemetry identity, Codebase Memory indexes, and caches remain local mutable state.
- Home Manager owns the exact reviewed shared policy and Prime settings files, not the entire `~/.prime/agent` directory.

## License

MIT No Attribution. See `LICENSE`.
