# Herdr Thin-Client Home Manager Plan

## Scope

Goal: maintain a single regular Ubuntu WSL Home Manager environment for AGY, Pi, Prime Agent, and Herdr, with an optional `orca-prime` Node 22/build-validation shell and Windows Herdr access through loopback SSH on branch `herdr-agents-nix`.

Non-goals:

- Do not change `origin/main`.
- Do not commit or push during planning.
- Do not run installers or package managers during planning.
- Do not commit credentials, SSH keys, Prime auth, sessions, daemon state, caches, npm cache, downloaded runtime packages, Orca or Herdr installers, or validation evidence.
- Do not claim Prime, Lavish, gh-axi, AGY, Pi, or Codebase Memory are reproducibly Nix-packaged until fixed-output Nix packaging exists and is validated.
- Do not allow AGY, Pi, Prime, or Firstmate to create, remove, move, or prune Herdr-owned worktrees. Agents may operate only inside a Herdr-assigned worktree.

Authority boundaries:

- Repository owns declarative, reviewable configuration only.
- Home Manager may own exact policy/config files for Prime/Lavish and public opt-in skill files.
- Home Manager owns the regular shell UX, Node 24, PATH, all three agent launchers, Herdr, shared policy/skill/MCP links, and pinned Nix packages for support tools; only the three primary agent binaries remain transitional script installs.
- The optional `orca-prime` shell owns Node 22, Python, uv, gh, jq, and build tooling for deterministic validation only. It is not required to launch Prime, AGY, Pi, or Firstmate.
- Ubuntu apt/systemd owns WSL host prerequisites: `openssh-server`, `build-essential`, `python3`, and the loopback `sshd` service. These must exist before Herdr can relay over SSH, so they cannot live only inside a per-user Nix shell.
- Windows PowerShell bootstrap owns Windows-side WSL name checks, `.wslconfig`, SSH key creation/copy, Herdr installer verification, and terminal/node-pty prerequisite checks.
- User owns secrets and auth: OpenAI/Prime auth, GitHub auth, Windows account secrets, SSH private keys, `authorized_keys` material before copy, session dirs, caches, and runtime downloads.
- Ricardo's verified Windows Herdr workflow is the source of truth for installer URL/checksum, expected Herdr version `0.8.2`, and smoke-test behavior. If repo text conflicts, use Ricardo's verified values after approval.

## Current migration decision: unified regular Home Manager agents

Status: inherited from `orca-agents-nix`; the Herdr branch-specific architecture below is authoritative. Target WSL activation and smoke validation remain required.

The regular Home Manager shell becomes the daily runtime for all three harnesses:

- Home Manager keeps Zsh, Starship, Git, Neovim, fonts, ABNT2, shortcuts, Node 24, `~/.local/bin`, and the persistent npm global bin path.
- AGY, Pi, and Prime are launched directly from that regular shell.
- `gh-axi`, `lavish-axi`, `no-mistakes`, `codebase-memory-mcp`, Firstmate, Treehouse, Caveman, and `i-have-adhd` are pinned Nix packages available from the same PATH.
- Caveman and the pinned `i-have-adhd` skill are exposed to all three harnesses through client-compatible skill roots.
- Pi, AGY, and Prime retain client-specific MCP configuration schemas but point at the same local Codebase Memory policy and binary.
- `nix develop .#orca-prime` remains available only for Node 22, Python, uv, gh, jq, compiler, and package validation. It is not required by any agent launcher.

The policy surface becomes one tracked root `AGENTS.md` linked to Pi, AGY, and Prime. Prime-specific safety, Firstmate worktree authority, Herdr SSH boundaries, Codebase Memory rules, telemetry boundaries, and engineering rules are merged into that common source. The tracked `home/.prime/agent/AGENTS.md` file is removed; Prime settings remain separately managed in `home/.prime/agent/settings.json`.

Firstmate becomes the user-owned project coordination home at `~/firstmate`, with project clones and Treehouse-managed crew worktrees under `~/firstmate/projects`. The dotfiles repository remains the installer and policy source; Firstmate's `data/`, `state/`, `config/`, sessions, caches, and project runtime state remain outside Git.

Firstmate owns project and crew worktree lifecycle through its reviewed Linux `tmux`/Treehouse backend. Windows Herdr connects to WSL over SSH and may inspect or operate inside an explicitly selected Firstmate worktree, but it does not create, move, remove, or prune worktrees. The pinned Firstmate macOS-only `orca` backend is not used in this topology.

Implementation order:

1. Update `PLAN.md`, `SPRINT_PLAN.md`, and the common policy contract.
2. Move agent launchers and the npm global bin path into the regular Home Manager module.
3. Package all support tools with fixed release hashes or lockfile integrity values; keep only AGY, Pi, and Prime Agent script-managed.
4. Link the common policy and skills to all three clients and preserve client-specific MCP schemas.
5. Package Firstmate and Treehouse while keeping `~/firstmate/projects` and all runtime state mutable outside the Nix store.
6. Retain `.#orca-prime` as an optional validation shell and remove agent-runtime assumptions from its launcher/tests.
7. Run static checks, activation builds, regular-shell smoke checks, direct harness version/help checks, MCP read-only checks, and Herdr SSH acceptance on WSL.

Acceptance criteria:

- A fresh regular Home Manager shell resolves `herdr`, `agy`, `pi`, `prime`, `prime-agent`, `gh-axi`, `lavish-axi`, `no-mistakes`, and `codebase-memory-mcp` without entering `nix develop`.
- All three harnesses load the same common `AGENTS.md`, Caveman, and pinned `i-have-adhd` skill through their supported paths.
- All three harnesses can perform a bounded read-only Codebase Memory query with the same local safety boundary.
- `nix develop .#orca-prime` still provides the pinned Node 22/build-validation toolchain.
- `~/firstmate/projects` is reachable from Herdr's WSL SSH terminal, and Firstmate's Linux Treehouse backend owns crew worktree lifecycle.
- The Windows Herdr client cannot create or remove Firstmate-owned worktrees through the SSH workflow.
- No credentials, sessions, caches, generated state, or project runtime data enter the dotfiles repository.

Nix packaging acceptance additions:

- `packages/default.nix` exposes fixed-output packages for Codebase Memory, no-mistakes, Firstmate, Treehouse, Lavish, gh-axi, Caveman, and `i-have-adhd`.
- The only installation scripts remaining for user agents are `install-home-agents.sh` and `install-prime-tools.sh`.
- Nix package outputs use release hashes or committed npm lockfile integrity values; no `lib.fakeHash` remains.

The earlier Prime-only shell, Prime-specific policy, and Prime-only skill-link requirements in Phases 3, 4, 7, 8, and 8C are historical records of the already-landed baseline. Where they conflict with this current migration decision, this unified Home Manager contract is authoritative.

## Herdr Thin-Client Migration - `herdr-agents-nix`

Branch `herdr-agents-nix` is based on `orca-agents-nix`. This variant replaces the Windows Orca client with Herdr while preserving the Ubuntu WSL SSH transport.

### Architecture

- The regular Home Manager profile owns the Linux Herdr package and authored `~/.config/herdr` link. The package moves out of the legacy-only module and is available in the normal home-agent shell.
- Update the pinned Herdr flake input from `v0.7.5` to the current stable `v0.8.2`, so the Linux server and Windows client share the release/protocol generation that supports Windows `herdr --remote`.
- Windows uses the reviewed official Herdr PowerShell installer from `https://herdr.dev/install.ps1`, with stable-channel behavior. Do not install Orca on Windows and remove the Orca installer option and Orca-specific documentation from this branch.
- Retain Ubuntu systemd, OpenSSH, key-only authentication, loopback binding, port `2222`, `AllowUsers`, and the existing managed sshd configuration. Herdr remote attach uses normal OpenSSH authentication and must not require a new server or public listener.
- Keep `~/firstmate/projects` as the Linux project root. The intended client command is `herdr --remote user@server:2222` or an SSH-config alias.
- User credentials, private keys, `authorized_keys`, Herdr sessions, caches, and runtime state remain outside Git.

### Implementation order

1. Move Herdr package/config ownership into the regular Home Manager module and remove its direct legacy declaration.
2. Update the locked Herdr input to stable `v0.8.2` and verify the flake lock changes are limited to that input and required dependencies.
3. Rename the Windows bootstrap to a Herdr/SSH bootstrap, remove Orca download/install/checksum logic, and add an explicit stable Herdr installation option using the reviewed official PowerShell installer. Preserve the WSL and SSH verification flow.
4. Update README, common policy, validation, smoke tests, repository map, and rollback text from Orca to Herdr where this branch changes the client. Keep the SSH server path and safety guarantees unchanged.
5. Run shell, PowerShell parser, JSON, Nix evaluation/build, and target WSL SSH/Herdr checks. Do not run the Windows installer or change host SSH state from the assistant environment.

### Acceptance criteria

- `herdr --version` resolves from the regular WSL Home Manager shell at stable `0.8.2` after activation.
- The legacy profile no longer declares a separate Herdr package/config link; it inherits the regular profile’s Herdr ownership.
- The Windows bootstrap has no Orca installation path and offers Herdr installation only behind explicit apply/install flags.
- Ubuntu sshd remains configured and validated at `127.0.0.1:2222`, with key-only authentication and no root login.
- Windows installation instructions use the official Herdr PowerShell installer, and remote attach is documented as `herdr --remote user@server:2222`.
- No Orca installer, credentials, private keys, sessions, caches, or generated runtime state is tracked.

## Proposed Repository Tree

```text
.
|-- AGENTS.md
|-- PLAN.md
|-- README.md
|-- bootstrap.sh
|-- rebuild.sh
|-- flake.nix
|-- flake.lock
|-- home.nix
|-- home/
|   |-- .agents/skills/
|   |   |-- caveman/                      # shared Caveman skill
|   |   `-- i-have-adhd/                  # shared pinned presentation skill
|   |-- .config/
|   |   |-- mcp/mcp.json                  # Pi shared MCP config
|   |   |-- nvim/                         # retained base editor config
|   |   |-- wezterm/                       # legacy module only
|   |   `-- herdr/                         # regular Home Manager Herdr config
|   |-- .gemini/config/mcp_config.json    # AGY MCP config
|   |-- .prime/
|   |   `-- agent/
|   |       `-- settings.json             # reviewed Prime settings only
|   `-- .pi/agent/                        # legacy module only
|-- modules/
|   |-- home-base.nix                     # shell UX, Node 24, Herdr, launchers and PATH
|   |-- home-common-agents.nix            # common AGENTS.md, skills, and MCP links
|   |-- home-firstmate.nix                # Firstmate launcher and tmux
|   |-- home-orca-prime.nix               # optional Prime settings and build-shell support
|   `-- home-legacy-agents.nix            # optional WezTerm/Pi/Claude/Codex fallback additions
|-- scripts/
|   |-- ubuntu-bootstrap.sh               # apt + sshd loopback prerequisites
|   |-- windows-herdr-bootstrap.ps1       # WSL/Herdr/SSH verification
|   |-- install-prime-tools.sh             # regular-shell pinned Prime install
|   |-- install-home-agents.sh             # reviewed AGY/Pi bootstrap install
|   `-- validate.sh                        # local validation wrapper, no evidence committed
|-- packages/
|   |-- default.nix                        # fixed-output support packages
|   `-- npm/                               # committed dependency lockfiles
|-- .no-mistakes.yaml                     # targeted gate policy, local-only evidence
`-- tests/
    |-- smoke-herdr-agents.sh               # regular shell and optional dev-shell checks
    `-- test-prime-maintenance.sh          # Prime maintenance safety checks
```

The original Orca migration phases below are retained as historical baseline only. They do not authorize a Windows Orca installation or replace the Herdr variant above.

## Decisions Needing Ricardo Approval

Known verified values:

- Common policy path: `AGENTS.md`, linked to `~/.pi/agent/AGENTS.md`, `~/.gemini/GEMINI.md`, and `~/.prime/agent/AGENTS.md`.
- Prime settings path: `~/.prime/agent/settings.json`.
- Shared skill paths: `~/.agents/skills/{caveman,i-have-adhd}`, plus client-compatible AGY and Prime links.
- Herdr stable release: `0.8.2`; Windows installer script: `https://herdr.dev/install.ps1`.
- Herdr Windows installer script SHA256: `3415ea0bc562cad003afcc70ac9916b81cde043c4c26087f05255ae7807d1ba7`.
- Prime installer source: `https://app.primeintellect.ai/prime-agent/install.sh`, invoked with version `0.8.0` only after review.
- npm packages: `lavish-axi@0.1.50` and `gh-axi@0.1.30`, installed with `--ignore-scripts --no-audit --no-fund` during the transitional phase.
- Codebase Memory MCP `0.10.8` portable Linux x86_64 release: `https://github.com/DeusData/codebase-memory-mcp/releases/download/v0.10.8/codebase-memory-mcp-linux-amd64-portable.tar.gz`.
- Codebase Memory MCP release SHA256: `6eef49652bc0c7820f43114125044d40bf7f4d97c11b2592f6b0f6a307702325`.
- no-mistakes `1.57.0` Linux x86_64 release SHA256: `1145e7bd41a013013eae4baa533d241322d20d917ffef732595460ddbf385b84`.
- AGY bootstrap script SHA256: `ee1ea43ce4e9e56356c4ab6dad907ef357ae4bdfcaadb682735909fb57c9c640`.
- Pi bootstrap script SHA256: `a3a3604ee550bf72c5da7da3c3014cc361c14ab3b91b1b24f097d9022bd8de5`.
- Firstmate commit: `038d0f7ec6ba7238a151722931434dcf06ff37c4`.

Approval choices before implementation:

- Legacy shape: recommended second Home Manager configuration `${user}@wsl-legacy`, not a runtime toggle inside the default profile.
- Global Node: **approved 2026-08-17** - keep Node 24 in the default Home Manager profile; `orca-prime` still uses Node 22 and its `PATH` takes precedence inside the shell.
- WSL distro handling: recommended verify exact registered name `Ubuntu` and fail closed; never rename an existing distro automatically.
- Shared policy: use the repository-root `AGENTS.md` for AGY, Pi, and Prime; merge Prime safety/worktree rules into that common source and remove the separate tracked Prime `AGENTS.md`.
- Firstmate home: use `~/firstmate` with `~/firstmate/projects`; Treehouse owns Linux project/crew worktrees.
- Worktree authority: Firstmate owns Linux Treehouse worktrees; Windows Herdr connects over SSH and does not create, move, remove, or prune them.

## Phased Tasks

### Phase 0 - Branch Safety and Inventory

Files: none initially.

Expected work:

- Verify current branch is `feat/orca-prime-codebase-memory`.
- Verify `origin/main` points at current backup commit and remains untouched.
- Record baseline with `git status --short --branch`.
- Inspect existing Home Manager files and current tracked agent/runtime boundaries.
- Confirm no `.no-mistakes/` evidence is staged or tracked.

Acceptance:

- Worktree changes are limited to planned implementation files.
- `main` and `origin/main` untouched.

### Phase 1 - Restructure Home Manager Modules

Files:

- `flake.nix`
- `home.nix`
- `modules/home-base.nix`
- `modules/home-orca-prime.nix`
- `modules/home-legacy-agents.nix`

Expected changes:

- Keep `homeConfigurations."${user}@wsl"` as primary WSL config.
- Move common packages/settings into `modules/home-base.nix`:
  - Zsh with autosuggestion/syntax highlighting.
  - Starship prompt.
  - Git defaults, without personal identity.
  - CLI utilities: `ripgrep`, `fd`, `fzf`, `jq`, `gh`, `lazygit`, `gnumake`, `gcc`, `pkg-config` if needed globally.
  - Node 24 remains installed globally through Home Manager, per Ricardo's approval.
  - Neovim config link.
  - Brazilian ABNT2 X/WSLg support via `setxkbmap`.
- Remove dangerous default aliases in Orca lane:
  - remove `cc = "claude --dangerously-skip-permissions"`
  - remove `co = "codex --ask-for-approval never --sandbox workspace-write"` or any equivalent full-auto alias.
- Keep `rebuild = "home-manager switch -b backup --flake ~/.dotfiles#${user}@wsl"`.
- Keep WezTerm, Herdr, and Pi authored package/config links in `modules/home-legacy-agents.nix`; the default profile's Pi CLI is installed separately through the user-owned transitional installer in Phase 8C.
- Expose legacy fallback explicitly, for example:
  - `homeConfigurations."${user}@wsl"` = Orca Prime default.
  - `homeConfigurations."${user}@wsl-legacy"` = base + legacy module.
- Remove `herdr` input from default path if only legacy uses it; keep input only while legacy profile needs it.
- Keep `home.stateVersion = "24.11"` unchanged unless Ricardo approves a state migration.

Acceptance:

- Orca default profile does not install or link WezTerm or Herdr. Pi's default-profile CLI remains user-owned and is not used for Orca worktree management.
- Legacy profile still can restore current WezTerm/Herdr/Pi fallback.

### Phase 2 - Add `orca-prime` Nix Dev Shell

Files:

- `flake.nix`
- optional `shells/orca-prime.nix` if split improves clarity.

Expected changes:

- Add `devShells.${system}.orca-prime`.
- Include exactly:
  - Node 22
  - Python 3
  - `uv`
  - `gh`
  - `jq`
  - `ripgrep`
  - `gnumake`
  - `gcc`
  - `pkg-config`
- Set verified env vars used by the current guide:
  - `NPM_CONFIG_PREFIX="$HOME/.local/share/npm"`
  - prepend `$HOME/.local/bin` and `$NPM_CONFIG_PREFIX/bin` to `PATH`
  - `PRIME_AGENT_TELEMETRY=0`
  - `PI_SKIP_VERSION_CHECK=1`
  - `LAVISH_AXI_TELEMETRY=0`
  - `LAVISH_AXI_NO_OPEN=1`
  - `LAVISH_AXI_HOST=127.0.0.1`
  - `CBM_ALLOWED_ROOT=/home/ricardo`
  - `CBM_CACHE_DIR=/home/ricardo/.cache/codebase-memory-mcp`
  - `CBM_DIAGNOSTICS=0`
- Document that Node 22 from the shell is authoritative for Orca Prime work.
- Keep global Home Manager `nodejs_24`; verify the dev shell resolves Node 22 ahead of it.

Acceptance:

- `nix develop .#orca-prime --command node --version` reports Node 22.
- `node --version` outside shell reports Node 24; inside `orca-prime` it reports Node 22.

### Phase 3 - Prime/Lavish Policy and Config Boundaries

Files:

- `home/.prime/agent/AGENTS.md`
- `home/.prime/agent/settings.json`
- `modules/home-orca-prime.nix`
- `.gitignore`

Expected changes:

- Add reviewed Prime-oriented `home/.prime/agent/AGENTS.md`; keep it separate from the shared root `AGENTS.md`.
- Keep policy public and non-secret.
- Link only exact reviewed config/policy files through Home Manager.
- Do not link whole mutable directories:
  - no `~/.prime` directory ownership unless only a fixed public skill subdir is linked.
  - no auth/session/cache/download/runtime dirs.
- Add `.gitignore` guards for likely runtime paths if repo-local mirrors exist:
  - `home/.prime/agent/auth*`
  - `home/.prime/agent/sessions/`
  - `home/.prime/agent/cache/`
  - `home/.prime/agent/downloads/`
  - `home/.local/share/npm/`
  - Windows key/output staging paths if scripts create any inside repo.

Acceptance:

- No auth/token/session/cache/runtime path is Home Manager-owned.
- Config files are reviewable JSON and pass parser checks.

### Phase 4 - Add Pinned `i-have-adhd` Skill Only

Files:

- `flake.nix`
- `flake.lock`
- `modules/home-orca-prime.nix`
- README skill section.

Expected changes:

- Add a non-flake input pinned to `github:ayghri/i-have-adhd/2ed064090711586e0c97a2fbbf15465fe8f1808b`.
- Link only `${i-have-adhd}/skills/i-have-adhd` to `~/.prime/agent/skills/i-have-adhd` through Home Manager.
- No hooks.
- No plugins.
- No installers.
- No auto-enable unless Prime's reviewed config supports opt-in by name.
- Do not vendor or copy the whole upstream repository into this repo.

Acceptance:

- Home Manager evaluates the exact skill link and the lockfile records its pin.
- No hook/plugin/installer files are linked into Prime.

### Phase 5 - Ubuntu WSL Bootstrap for SSH Relay

Files:

- `scripts/ubuntu-bootstrap.sh`
- `README.md`

Expected changes:

- Add idempotent Ubuntu script for prerequisites before Orca relay:
  - install/check `openssh-server`, `build-essential`, `python3`
  - create/update an sshd config snippet for loopback-only `127.0.0.1:2222`
  - key-only auth
  - no root login
  - no password auth
  - no keyboard-interactive auth
  - explicit `AuthorizedKeysFile`
  - restart `ssh` service safely under WSL
- Explain apt/system prerequisites:
  - `sshd` is a system daemon and must bind a host port before user shells start.
  - Orca's Windows terminal relay connects to WSL over SSH before any Nix dev shell can provide binaries.
  - Build essentials and Python are expected by node-pty/native modules during bootstrap/install before Nix shell may exist.
- Avoid managing user private keys in WSL script.

Acceptance:

- `sshd -t` passes.
- `ss -ltnp` shows loopback bind only: `127.0.0.1:2222`, not `0.0.0.0:2222`.
- Password/root login disabled in effective sshd config.

### Phase 6 - Windows PowerShell Bootstrap and Verification

Files:

- `scripts/windows-orca-bootstrap.ps1`
- `README.md`

Expected changes:

- Verify WSL distro name exactly `Ubuntu` with `wsl.exe -l -v`.
- Write or verify `%UserProfile%\.wslconfig` settings needed by Ricardo's workflow.
- Generate dedicated SSH key only if absent at `%UserProfile%\.ssh\orca-wsl-ed25519`.
- Copy public key into Ubuntu user's `~/.ssh/authorized_keys` with correct permissions via `wsl.exe -d Ubuntu`.
- Download Orca `1.4.184` from `https://github.com/stablyai/orca/releases/download/v1.4.184/orca-windows-setup.exe` and require SHA256 `7765f7f085d04b7fe662ec664825fedd81427dd586023f945182a46e0a0cf5be` before execution.
- Verify Windows prerequisites:
  - Orca installed version `1.4.184`
  - SSH client available
  - WSL `Ubuntu` reachable
  - loopback SSH to `127.0.0.1:2222`
  - terminal/node-pty prerequisite path from Ricardo's smoke test.
- Never print private key material or secrets.

Acceptance:

- Script supports `-VerifyOnly` mode.
- Script fails closed on wrong distro name, checksum mismatch, missing key auth, or password auth.
- No key material or installer binary is committed.

### Phase 7 - Initial Prime/Lavish/gh-axi Tool Install Path

Files:

- `scripts/install-prime-tools.sh`
- `README.md`
- `.gitignore`

Expected changes:

- Use reviewed pinned installer/npm prefix under user-owned runtime path, not repo:
  - Prime `0.8.0`
  - Lavish `0.1.50`
  - gh-axi `0.1.30`
- Run inside `nix develop .#orca-prime`.
- Install AXI packages into `NPM_CONFIG_PREFIX="$HOME/.local/share/npm"`, matching the verified current guide.
- Record exact package names, versions, checksums/integrity values, and audit notes in script comments or README.
- State clearly this is a pinned reviewed installer path, not reproducible Nix packaging.

Later phase:

- Replace installer path with fixed-output Nix or `buildNpmPackage` derivations.
- Pin source tarballs and hashes in Nix.
- Build wrappers with exact runtime env.
- Add `nix flake check` coverage for packages.
- Remove installer script only after parity validation.

Acceptance:

- Version checks pass:
  - `prime-agent --version` -> `0.8.0`
  - `lavish-axi --version` -> `0.1.50`
  - `gh-axi --version` -> `0.1.30`
- README does not describe these tools as reproducibly Nix-packaged yet.

### Phase 8 - Codebase Memory MCP Integration

Files:

- `home/.prime/agent/settings.json`
- `modules/home-orca-prime.nix`
- `flake.nix`
- `scripts/install-codebase-memory.sh`
- `scripts/validate.sh`
- `tests/smoke-orca-prime.sh`
- `README.md`
- `.gitignore`

Expected changes:

- Configure Prime 0.8.0 generic MCP runtime with `mcpServers.codebase_memory`.
- Use stdio command `/home/ricardo/.local/bin/codebase-memory-mcp`, cwd `/home/ricardo/src`, startup timeout `30000`, and call timeout `120000`.
- Pass env references for `CBM_ALLOWED_ROOT`, `CBM_CACHE_DIR`, and `CBM_DIAGNOSTICS`.
- Disable initial mutating/high-risk tools with `disabledTools`: `delete_project`, `manage_adr`, and `ingest_traces`.
- Leave indexing and read/query tools available with the approved `auto_index=true` and `auto_watch=true` settings; do not enable the optional UI initially.
- Install Codebase Memory MCP `0.10.8` through `scripts/install-codebase-memory.sh` only inside `nix develop .#orca-prime`.
- Verify release SHA256 before extraction, use private temp state, install mode `0755` to `$HOME/.local/bin`, and verify `--version`.
- Do not make Home Manager own cache/index state. No committed `.codebase-memory` or graph artifact.
- Document install, manual indexing/usage, local-only cache boundaries, rollback, and uninstall.

Acceptance:

- `jq empty home/.prime/agent/settings.json` passes.
- `bash -n scripts/install-codebase-memory.sh` passes.
- `./scripts/install-codebase-memory.sh` followed by `codebase-memory-mcp --version` reports `0.10.8` from the regular Home Manager shell.
- `git ls-files '.codebase-memory/**' 'home/.cache/codebase-memory-mcp/**'` is empty.

### Phase 8A - Prime Maintenance Utility

Files:

- `scripts/prime-maintenance.py`
- `modules/home-base.nix`
- `scripts/validate.sh`
- `tests/smoke-orca-prime.sh`
- `tests/test-prime-maintenance.sh`
- `README.md`

Expected changes:

- Provide a `prime-maintenance` launcher for listing Prime agents and saved sessions.
- Use Prime 0.8.0 lifecycle commands for stopping one agent or all agents.
- Provide `prime-maintenance clean-unnamed` to stop all agents and clean only unnamed saved sessions while preserving named sessions.
- Parse only session metadata from JSONL files. Never print prompts, transcripts, tool output, auth, or session contents.
- Require explicit confirmation for destructive actions.
- Prefer `trash` or `gio trash` for session deletion. Permit permanent deletion only with `--permanent`.
- Refuse active-session deletion until the owning agent is stopped.
- Keep session paths contained below the configured Prime session directory.
- Test listing, redaction, containment, active-session refusal, and confirmation behavior with disposable fixtures only.

Acceptance:

- `prime-maintenance --help` works after Home Manager activation.
- `tests/test-prime-maintenance.sh` passes without invoking real Prime lifecycle commands.
- `clean-unnamed` requires confirmation, verifies shutdown through the mocked lifecycle command, removes only unnamed disposable sessions, and preserves named sessions.
- No session content or runtime state is committed.

### Phase 8B - no-mistakes Repository Integration

Files:

- `.no-mistakes.yaml`
- `scripts/install-no-mistakes.sh`
- `modules/home-base.nix`
- `flake.nix`
- `scripts/validate.sh`
- `tests/smoke-orca-prime.sh`
- `README.md`
- `PLAN.md`
- `.gitignore`

Expected changes:

- Pin no-mistakes `1.57.0` Linux x86_64 and verify its release SHA256 before extraction.
- Install the user-owned binary under `~/.no-mistakes/bin` with a `~/.local/bin` command link.
- Keep telemetry and automatic update checks disabled in both the regular Home Manager shell and the `orca-prime` development shell.
- Add targeted shell and Prime maintenance checks without a repository-wide local regression command.
- Keep validation evidence in no-mistakes-managed local state and never commit `.no-mistakes/`.
- Do not run `no-mistakes init`, modify Git remotes, start the daemon, or start a gate during repository installation.

Acceptance:

- `bash -n scripts/install-no-mistakes.sh` passes.
- The pinned release archive checksum passes in a disposable install directory.
- The disposable installed binary reports `1.57.0`.
- `git diff --check` passes and no runtime state or credentials are tracked.
- Target Ubuntu WSL smoke testing reports no-mistakes version and telemetry policy after explicit installation.

### Phase 8C - Default Home Manager AGY and Pi Installation

Files:

- `modules/home-base.nix`
- `modules/home-common-agents.nix`
- `home/.agents/skills/caveman/SKILL.md`
- `home/.config/mcp/mcp.json`
- `home/.gemini/config/mcp_config.json`
- `home/.pi/agent/settings.json`
- `scripts/install-home-agents.sh`
- `scripts/validate.sh`
- `tests/smoke-orca-prime.sh`
- `.gitignore`
- `README.md`
- `AGENTS.md`
- `PLAN.md`
- `SPRINT_PLAN.md`

Expected changes:

- Add `~/.local/bin` to the regular Home Manager shell PATH and provide `curl` for reviewed installers.
- Verify the upstream AGY and Pi bootstrap script SHA256 values before executing them.
- Require Node/npm from the Home Manager shell so the Pi installer does not bootstrap system packages or invoke `sudo`.
- Install user-owned `agy` and `pi` launchers without linking auth, sessions, caches, logs, or downloads into the repository.
- Expose one shared root `AGENTS.md` to Pi and AGY, remove duplicate `home/AGENTS.md`, and keep Prime's policy separate.
- Install the pinned Pi MCP adapter and expose the same local Codebase Memory server to Pi and AGY with destructive tools disabled.
- Expose the reviewed Caveman skill through both agents' global skill roots.
- Document that the bootstrap scripts resolve dynamic upstream releases and are not reproducible Nix packages.
- Keep AGY/Pi out of Orca worktree management; they are shell tools only.

Acceptance:

- `bash -n scripts/install-home-agents.sh` passes.
- Home Manager configuration evaluates with the user-owned PATH and explicit `curl` package.
- Target regular-shell smoke testing reports `agy --version` and `pi --version` after explicit installation.
- Pi lists `pi-mcp-adapter`, both MCP configurations parse, and both contain the expected Codebase Memory safety restrictions.
- The live tracked policy set contains only root `AGENTS.md` and Prime's `home/.prime/agent/AGENTS.md`.
- Runtime/auth/session/cache/download paths remain untracked.

### Phase 9 - Rewrite README for Ubuntu WSL + Orca

Files:

- `README.md`
- `AGENTS.md`

Expected changes:

- Remove stale Mac/nix-darwin narrative.
- Document target:
  - Windows Orca `1.4.184`
  - WSL distro name exactly `Ubuntu`
  - Ubuntu Home Manager profile
  - loopback SSH `127.0.0.1:2222`
  - `nix develop .#orca-prime`
  - Prime/Lavish/gh-axi pinned installer phase
  - AGY/Pi Home Manager-shell transitional installer phase
- Explain bootstrap order:
  1. Windows prerequisites and `.wslconfig`
  2. Ubuntu apt/system prerequisites
  3. Determinate Nix/Home Manager bootstrap
  4. `orca-prime` shell
  5. Prime tools install/verification
  6. Orca SSH terminal smoke test
- Warn about secrets and what is intentionally unmanaged.
- Document legacy fallback profile and rule: do not use WezTerm/Herdr/Pi in Orca-owned worktrees.
- Update repository `AGENTS.md`:
  - remove the stale Homebrew/nix-darwin `configuration.nix` note because that file is absent.
  - retain the `.no-mistakes/` prohibition.
  - add the Orca/Prime authority and secrets boundaries.

Acceptance:

- README no longer claims this is Mac/nix-darwin setup.
- Fresh setup instructions match actual files/scripts.

## Migration Path

1. Keep `origin/main` as unchanged backup.
2. On feature branch, add Orca default profile without deleting legacy files first.
3. Add `wsl-legacy` Home Manager config that links current WezTerm/Herdr/Pi files.
4. Apply default Orca profile in WSL:
   `home-manager switch -b backup --flake ~/.dotfiles#$(whoami)@wsl`
5. Use legacy fallback only if needed:
   `home-manager switch -b backup --flake ~/.dotfiles#$(whoami)@wsl-legacy`
6. If Orca path fails, switch back to legacy profile or reclone/reset local feature branch from `origin/main`.
7. Do not change Windows Orca or SSH key state until verification scripts pass in dry/verify mode.

Rollback:

- Home Manager generation rollback:
  - run `home-manager generations`.
  - execute the previous generation's `activate` path shown by that command.
- Git rollback of feature branch only:
  `git switch feat/orca-prime-home-manager`
  `git restore <file>` for local uncommitted implementation mistakes.
- Full backup fallback:
  `git switch main` or fresh clone from `origin/main`; do not force-push or rewrite backup branch.
- Ubuntu sshd rollback:
  remove/disable repo-created sshd config snippet, then `sudo systemctl restart ssh`.
- Windows rollback:
  remove Orca-specific `.wslconfig` entries only if they were added by script and documented;
  remove dedicated public key line from WSL `authorized_keys`;
  keep private key deletion manual unless Ricardo approves automated deletion.

## Security and Secrets

- Never commit:
  - private keys
  - public/private credential pairs
  - tokens
  - `authorized_keys` snapshots
  - Prime/Lavish auth
  - session transcripts
  - caches
  - npm/git runtime package downloads
  - Orca installer binaries
  - `.no-mistakes/` evidence
- SSH relay:
  - bind only `127.0.0.1:2222`
  - key-only auth
  - no root login
  - no password auth
  - no keyboard-interactive auth
  - dedicated key for Orca only
- Home Manager:
  - own exact files, not mutable app dirs.
  - link `settings.json` and policy files only after review.
  - do not manage trust decisions or login state.
- Installer phase:
  - verify checksums/integrity before execution.
  - pin versions.
  - document non-reproducible boundary until Nix packaging phase lands.

## Validation Commands

Run after implementation, not during planning unless explicitly approved.

Syntax and static checks:

```sh
bash -n bootstrap.sh
bash -n rebuild.sh
bash -n scripts/ubuntu-bootstrap.sh
bash -n scripts/install-prime-tools.sh
jq empty home/.prime/agent/settings.json
git ls-files -z | xargs -0 rg -n --hidden --glob '!.git/**' 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|ghp_[A-Za-z0-9_]+|sk-[A-Za-z0-9_-]+'
```

PowerShell checks where available:

```powershell
powershell.exe -NoProfile -Command "$errors=$null; [System.Management.Automation.PSParser]::Tokenize((Get-Content .\scripts\windows-orca-bootstrap.ps1 -Raw), [ref]$errors) > $null; if ($errors) { $errors; exit 1 }"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows-orca-bootstrap.ps1 -VerifyOnly
```

Nix checks:

```sh
nix flake check
nix build '.#homeConfigurations."ricardo@wsl".activationPackage'
nix build '.#homeConfigurations."ricardo@wsl-legacy".activationPackage'
home-manager switch --dry-run --flake "$PWD#$(whoami)@wsl"
nix develop .#orca-prime --command node --version
nix develop .#orca-prime --command python3 --version
nix develop .#orca-prime --command uv --version
nix develop .#orca-prime --command gh --version
```

Ubuntu SSH checks:

```sh
sudo sshd -t
ss -ltnp | rg '127\.0\.0\.1:2222'
sudo sshd -T -f /etc/ssh/sshd_config | rg '^(passwordauthentication no|kbdinteractiveauthentication no|permitrootlogin no|pubkeyauthentication yes)'
# Run the key-authentication check from Windows; the dedicated private key is not stored inside WSL.
```

Prime/Lavish/gh-axi checks:

```sh
nix develop .#orca-prime --command prime-agent --version
nix develop .#orca-prime --command lavish-axi --version
nix develop .#orca-prime --command gh-axi --version
nix develop .#orca-prime --command codebase-memory-mcp --version
```

Expected versions:

- Prime `0.8.0`
- Lavish `0.1.50`
- gh-axi `0.1.30`
- Codebase Memory MCP `0.10.8`

Orca smoke:

```powershell
$Key = "$env:USERPROFILE\.ssh\orca-wsl-ed25519"
$WslUser = (wsl.exe -d Ubuntu -- bash -lc 'printf %s "$USER"').Trim()
$Target = '{0}@127.0.0.1' -f $WslUser
ssh.exe -i $Key -p 2222 $Target 'uname -s; pwd; git --version'
# Then verify Orca itself opens the SSH worktree terminal without the node-pty error.
```

Acceptance criteria:

- All shell/PowerShell parsers pass.
- `nix flake check` passes.
- Default and legacy activation packages build.
- Home Manager dry-run has no unexpected ownership of auth/runtime paths.
- Secret scan returns no hits.
- SSH listens only on loopback port `2222`.
- SSH key auth works and password/root auth do not.
- Orca can open WSL terminal through SSH relay and node-pty smoke passes.
- Version checks match approved pins.

## Commit Strategy

Small logical commits after implementation and validation:

1. `refactor: split WSL home-manager modules`
   - base module, Orca default, legacy fallback profile.
2. `feat: add orca-prime dev shell`
   - Node 22 shell and env vars.
3. `feat: add Prime policy and skill config`
   - reviewed settings, `AGENTS.md`, pinned `i-have-adhd` only.
4. `feat: add WSL SSH bootstrap scripts`
   - Ubuntu and Windows scripts, no secrets.
5. `docs: rewrite README for Orca WSL`
   - accurate setup, validation, rollback.
6. `test: add validation smoke scripts`
   - syntax/no-secret/version/SSH smoke checks.

Before each commit:

```sh
git status --short
git diff --check
```

Do not commit `.no-mistakes/`, keys, installers, generated caches, or local auth.

## GitHub Branch, Push, and PR Procedure

Current branch should remain:

```sh
git branch --show-current
# feat/orca-prime-home-manager
```

`gh` is currently unauthenticated in this environment, so PR creation may fail until Ricardo authenticates:

```sh
gh auth status
```

After implementation and validation, push feature branch only:

```sh
git push -u origin feat/orca-prime-home-manager
```

Create PR only after authentication:

```sh
gh pr create \
  --base main \
  --head feat/orca-prime-home-manager \
  --title "Add Orca Prime WSL Home Manager setup" \
  --body-file PR.md
```

If `gh` remains unauthenticated, use GitHub web UI after pushing branch. Do not push or alter `main`.

## Known Uncertainties and Blockers

- Exact Prime installer behavior at `0.8.0` must be re-reviewed immediately before implementation; do not use an uninspected `curl | sh` path.
- Codebase Memory auto indexing and file watching are intentionally enabled by the approved Prime runtime configuration and remain restricted to `/home/ricardo/src`.
- `i-have-adhd` is pinned to reviewed commit `2ed064090711586e0c97a2fbbf15465fe8f1808b`; implementation must still verify that the expected `skills/i-have-adhd` path exists in the locked input.
- Node 24 global retention is approved; validation must catch accidental leakage into the Node 22 `orca-prime` shell.
- PowerShell validation depends on Windows host availability; Linux-only CI can only parser-check if `pwsh`/`powershell.exe` exists.
- Orca terminal/node-pty smoke test requires Windows GUI/Orca context and cannot be fully proven from headless WSL alone.
- `gh` is unauthenticated in this implementation environment, so no push or PR can occur until Ricardo authorizes/authenticates GitHub access.
- This host has no native `nix` executable. A pinned `nixos/nix:2.28.5` Docker validator is available for isolated flake evaluation/build checks; target activation and Orca runtime acceptance still require Ricardo's Ubuntu WSL.
