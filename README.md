# dotfiles: Ubuntu WSL, Orca, and Prime

This repository is the authoritative Home Manager configuration for Ricardo's Ubuntu WSL development environment.

The default lane is:

```text
Windows 10
└── Orca 1.4.184
    └── SSH 127.0.0.1:2222
        └── Ubuntu WSL2 distro "Ubuntu"
            └── Linux repository/worktree under /home/...
                ├── Home Manager: Zsh, Starship, Git, CLI tools, Neovim, ABNT2, Node 24
                └── nix develop .#orca-prime: Node 22, Python, uv, gh, build tools, Prime
```

The previous WezTerm, Herdr, Pi, Claude Code, and Codex environment remains available as the optional `legacy` Home Manager profile. It is not loaded by the default Orca/Prime profile.

## Responsibility boundaries

| Layer | Owns |
|---|---|
| Windows and Ubuntu bootstrap | WSL resources, systemd, OpenSSH, `127.0.0.1:2222`, `build-essential`, global `python3` |
| Home Manager | Zsh, Starship, Git, user CLI tools, Neovim, ABNT2, global Node 24, reviewed Prime policy |
| `.#orca-prime` | Node 22, Python, uv, gh, jq, ripgrep, make, GCC, pkg-config, agent environment variables |
| Orca | Project registration, worktree creation/reuse/removal, editor, diffs, browser, terminals |
| Prime | Coding and reasoning inside the current Orca-owned worktree only |

Orca's SSH relay starts before `nix develop`. Therefore Ubuntu must provide `/usr/bin/make`, `/usr/bin/g++`, and `/usr/bin/python3` globally. The matching Nix packages supplement those host prerequisites; they do not replace them.

## Fixed versions and pins

- WSL distro name: `Ubuntu`
- Orca: `1.4.184`
- Orca installer SHA-256: `7765f7f085d04b7fe662ec664825fedd81427dd586023f945182a46e0a0cf5be`
- Prime Agent: `0.7.2`
- Lavish AXI: `0.1.50`
- gh-axi: `0.1.30`
- `i-have-adhd`: commit `2ed064090711586e0c97a2fbbf15465fe8f1808b`, skill directory only

`flake.lock` pins Nix inputs and the `i-have-adhd` source. `scripts/install-prime-tools.sh` verifies the reviewed Prime installer hash and npm package integrity before installation.

## Security model

- Repositories and worktrees live under `/home/...`, never `/mnt/c`.
- Use Linux Git only for those repositories.
- Orca is the only worktree manager in the default lane.
- Prime is not a sandbox and must never run as root.
- Prime telemetry is disabled in both the dev shell and `~/.prime/agent/settings.json`.
- Lavish is restricted to `127.0.0.1` and must not publish or share artifacts.
- gh-axi begins read-only.
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

### 4. Enter the locked Orca/Prime environment

```bash
cd ~/.dotfiles
nix develop .#orca-prime
```

Inside the shell, Node 22 must take precedence even though Home Manager provides global Node 24:

```bash
node --version
python3 --version
uv --version
```

Expected Node major version inside the shell: `v22`.

Install the pinned transitional agent tools only after reviewing the script:

```bash
./scripts/install-prime-tools.sh
```

The installer uses user-owned locations. It does not require root and must never be run with `sudo`.

After the tools are installed, the default Home Manager profile provides a
`prime` launcher. It can be called from the regular Node 24 shell and runs only
Prime inside the pinned Node 22 environment:

```bash
prime
```

Arguments are forwarded to `prime-agent`, for example `prime --help`. The
equivalent expanded command is:

```bash
nix develop ~/.dotfiles#orca-prime --command prime-agent
```

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

Initial operating limits are defined in `home/.prime/agent/AGENTS.md`: one root agent, no autonomous schedules or recursive write-heavy agents, gh-axi read-only, and no publication or external side effects without approval.

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

## Repository map

- `flake.nix`: Home Manager profiles, locked Orca/Prime dev shell, Home Manager app.
- `modules/home-base.nix`: default user packages and shell/editor configuration.
- `modules/home-orca-prime.nix`: reviewed Prime settings, policy, and pinned opt-in skill.
- `modules/home-legacy-agents.nix`: WezTerm, Herdr, Pi, Claude Code, and Codex fallback.
- `scripts/ubuntu-bootstrap.sh`: Ubuntu system and sshd bootstrap.
- `scripts/windows-orca-bootstrap.ps1`: Windows resources, dedicated SSH key, optional Orca installer.
- `scripts/install-prime-tools.sh`: pinned transitional Prime/Lavish/gh-axi installation.
- `scripts/validate.sh`: static, secret, flake, profile, and dev-shell validation.
- `tests/smoke-orca-prime.sh`: target-runtime acceptance checks.
- `home/`: repository-authored configuration linked by Home Manager.

## Notes

- The first Neovim launch bootstraps `lazy.nvim` from GitHub.
- Prime auth, sessions, daemon state, provider credentials, telemetry identity, and caches remain local mutable state.
- Home Manager owns exact reviewed Prime policy files, not the entire `~/.prime/agent` directory.

## License

MIT No Attribution. See `LICENSE`.
