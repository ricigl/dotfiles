# Orca Prime Home Manager Plan

## Scope

Goal: merge this repository's Ubuntu WSL Home Manager base with Ricardo's verified Windows Orca -> loopback SSH -> Ubuntu WSL -> Prime Agent workflow on branch `feat/orca-prime-home-manager`, while preserving `origin/main` unchanged as backup.

Non-goals:

- Do not change `origin/main`.
- Do not commit or push during planning.
- Do not run installers or package managers during planning.
- Do not commit credentials, SSH keys, Prime auth, sessions, daemon state, caches, npm cache, downloaded runtime packages, Orca installers, or validation evidence.
- Do not claim Prime, Lavish, or gh-axi are reproducibly Nix-packaged until fixed-output Nix packaging exists and is validated.
- Do not include WezTerm, Herdr, or Pi in Orca-owned worktrees except through an explicit optional legacy profile.

Authority boundaries:

- Repository owns declarative, reviewable configuration only.
- Home Manager may own exact policy/config files for Prime/Lavish and public opt-in skill files.
- Ubuntu apt/systemd owns WSL host prerequisites: `openssh-server`, `build-essential`, `python3`, and the loopback `sshd` service. These must exist before Orca can relay over SSH, so they cannot live only inside a per-user Nix shell.
- Windows PowerShell bootstrap owns Windows-side WSL name checks, `.wslconfig`, SSH key creation/copy, Orca installer verification, and terminal/node-pty prerequisite checks.
- User owns secrets and auth: OpenAI/Prime auth, GitHub auth, Windows account secrets, SSH private keys, `authorized_keys` material before copy, session dirs, caches, and runtime downloads.
- Ricardo's verified Windows Orca workflow is the source of truth for installer URL/checksum, expected Orca version `1.4.184`, and smoke-test behavior. If repo text conflicts, use Ricardo's verified values after approval.

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
|   |-- .config/
|   |   |-- nvim/                         # retained base editor config
|   |   |-- wezterm/                      # legacy module only
|   |   `-- herdr/                        # legacy module only
|   |-- .prime/
|   |   `-- agent/
|   |       |-- AGENTS.md                 # reviewed Prime policy only
|   |       `-- settings.json             # reviewed Prime settings only
|   `-- .pi/agent/                        # legacy module only
|-- modules/
|   |-- home-base.nix                     # Zsh, Starship, Git, CLI utils, Neovim, ABNT2
|   |-- home-orca-prime.nix               # Prime/Lavish policy links, no auth/runtime
|   `-- home-legacy-agents.nix            # optional WezTerm/Herdr/Pi fallback profile
|-- scripts/
|   |-- ubuntu-bootstrap.sh               # apt + sshd loopback prerequisites
|   |-- windows-orca-bootstrap.ps1        # WSL/Orca/SSH setup and verification
|   |-- install-prime-tools.sh            # reviewed pinned npm/prefix install, not Nix-packaged
|   `-- validate.sh                       # local validation wrapper, no evidence committed
`-- tests/
    `-- smoke-orca-prime.sh               # SSH/node-pty/version smoke checks
```

Tree can be flattened if Ricardo prefers fewer files, but module boundaries should stay clear: base, Orca Prime, legacy fallback, bootstrap, validation.

## Decisions Needing Ricardo Approval

Known verified values:

- Prime policy/settings paths: `~/.prime/agent/AGENTS.md` and `~/.prime/agent/settings.json`.
- Prime skill path: `~/.prime/agent/skills/i-have-adhd`.
- Orca `1.4.184` installer URL: `https://github.com/stablyai/orca/releases/download/v1.4.184/orca-windows-setup.exe`.
- Orca installer SHA256: `7765f7f085d04b7fe662ec664825fedd81427dd586023f945182a46e0a0cf5be`.
- Prime installer source: `https://app.primeintellect.ai/prime-agent/install.sh`, invoked with version `0.7.2` only after review.
- npm packages: `lavish-axi@0.1.50` and `gh-axi@0.1.30`, installed with `--ignore-scripts --no-audit --no-fund` during the transitional phase.

Approval choices before implementation:

- Legacy shape: recommended second Home Manager configuration `${user}@wsl-legacy`, not a runtime toggle inside the default profile.
- Global Node: **approved 2026-08-17** - keep Node 24 in the default Home Manager profile; `orca-prime` still uses Node 22 and its `PATH` takes precedence inside the shell.
- WSL distro handling: recommended verify exact registered name `Ubuntu` and fail closed; never rename an existing distro automatically.
- Prime policy: use a dedicated Orca/Prime policy at `home/.prime/agent/AGENTS.md`; preserve the existing `home/AGENTS.md` unless separately reviewed.

## Phased Tasks

### Phase 0 - Branch Safety and Inventory

Files: none initially.

Expected work:

- Verify current branch is `feat/orca-prime-home-manager`.
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
- Keep `rebuild = "home-manager switch --flake ~/.dotfiles#${user}@wsl"`.
- Move WezTerm, Herdr, and Pi package/config links into `modules/home-legacy-agents.nix`.
- Expose legacy fallback explicitly, for example:
  - `homeConfigurations."${user}@wsl"` = Orca Prime default.
  - `homeConfigurations."${user}@wsl-legacy"` = base + legacy module.
- Remove `herdr` input from default path if only legacy uses it; keep input only while legacy profile needs it.
- Keep `home.stateVersion = "24.11"` unchanged unless Ricardo approves a state migration.

Acceptance:

- Orca default profile does not install or link WezTerm, Herdr, or Pi.
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
  - prepend `$NPM_CONFIG_PREFIX/bin` to `PATH`
  - `PRIME_AGENT_TELEMETRY=0`
  - `PI_SKIP_VERSION_CHECK=1`
  - `LAVISH_AXI_TELEMETRY=0`
  - `LAVISH_AXI_NO_OPEN=1`
  - `LAVISH_AXI_HOST=127.0.0.1`
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

- Add reviewed Prime-oriented `home/.prime/agent/AGENTS.md`; do not silently replace the existing cross-agent `home/AGENTS.md`.
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
  - Prime `0.7.2`
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
  - `prime-agent --version` -> `0.7.2`
  - `lavish-axi --version` -> `0.1.50`
  - `gh-axi --version` -> `0.1.30`
- README does not describe these tools as reproducibly Nix-packaged yet.

### Phase 8 - Rewrite README for Ubuntu WSL + Orca

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
   `home-manager switch --flake ~/.dotfiles#$(whoami)@wsl`
5. Use legacy fallback only if needed:
   `home-manager switch --flake ~/.dotfiles#$(whoami)@wsl-legacy`
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
```

Expected versions:

- Prime `0.7.2`
- Lavish `0.1.50`
- gh-axi `0.1.30`

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

- Exact Prime installer behavior at `0.7.2` must be re-reviewed immediately before implementation; do not use an uninspected `curl | sh` path.
- `i-have-adhd` is pinned to reviewed commit `2ed064090711586e0c97a2fbbf15465fe8f1808b`; implementation must still verify that the expected `skills/i-have-adhd` path exists in the locked input.
- Node 24 global retention is approved; validation must catch accidental leakage into the Node 22 `orca-prime` shell.
- PowerShell validation depends on Windows host availability; Linux-only CI can only parser-check if `pwsh`/`powershell.exe` exists.
- Orca terminal/node-pty smoke test requires Windows GUI/Orca context and cannot be fully proven from headless WSL alone.
- `gh` is unauthenticated in this implementation environment, so no push or PR can occur until Ricardo authorizes/authenticates GitHub access.
- This host has no native `nix` executable. A pinned `nixos/nix:2.28.5` Docker validator is available for isolated flake evaluation/build checks; target activation and Orca runtime acceptance still require Ricardo's Ubuntu WSL.
