# Sprint Plan: Orca Prime Home Manager

Planning only. No implementation until Ricardo approves coding start.

Hard gates:

- Gate A: explicit approval before any source edit beyond this `SPRINT_PLAN.md`.
- Gate B: explicit approval before any host-mutating bootstrap run on Ubuntu or Windows.
- Gate C: explicit approval before push or PR.

Constraints:

- Branch stays `feat/orca-prime-home-manager`.
- `origin/main` remains unchanged backup.
- Keep global Node 24 in default Home Manager profile.
- `orca-prime` shell must resolve Node 22 before global Node 24.
- Prime config path: `~/.prime/agent/settings.json`.
- Prime policy path: `~/.prime/agent/AGENTS.md`.
- Prime skill path: `~/.prime/agent/skills/i-have-adhd`.
- Tool binaries: `prime-agent`, `lavish-axi`, `gh-axi`.
- Windows SSH key: `%USERPROFILE%\.ssh\orca-wsl-ed25519`.
- `gh auth status` currently fails because this environment is unauthenticated.
- This host has no native `nix` executable. Use the pinned `nixos/nix:2.28.5` Docker validator for isolated flake evaluation/build checks; do not claim target activation or Orca runtime acceptance until Ricardo verifies them in Ubuntu WSL.

## Sprint 1: Home Manager Split, Default, Legacy

1. Task: branch and inventory gate
   - Goal: prove starting point before code.
   - Exact files: none.
   - Implementation contract: run read-only inventory only.
   - Forbidden scope: no edits, commits, push, package manager, installer, Home Manager switch.
   - Verification commands: `git branch --show-current`; `git status --short --branch`; `git ls-files .no-mistakes`.
   - Completion criteria: branch is `feat/orca-prime-home-manager`; no `.no-mistakes/` tracked or staged; `origin/main` untouched.
   - Logical commit message: none.

2. Task: split base/default/legacy modules
   - Goal: make Orca Prime default WSL profile and keep legacy fallback.
   - Exact files: `flake.nix`, `home.nix`, `modules/home-base.nix`, `modules/home-orca-prime.nix`, `modules/home-legacy-agents.nix`.
   - Implementation contract: keep `homeConfigurations."${user}@wsl"` as default; add `homeConfigurations."${user}@wsl-legacy"`; move Zsh, Starship, Git defaults, CLI utilities, Neovim link, ABNT2 support, global Node 24, and `rebuild` alias into base; move WezTerm/Herdr/Pi into legacy only; keep `home.stateVersion = "24.11"`.
   - Forbidden scope: no WezTerm/Herdr/Pi in default Orca lane; no personal Git identity; no `cc = "claude --dangerously-skip-permissions"`; no `co = "codex --ask-for-approval never --sandbox workspace-write"` or equivalent full-auto alias; no `homebrew.onActivation.cleanup` changes.
   - Verification commands: `nix flake check`; `nix build '.#homeConfigurations."ricardo@wsl".activationPackage'`; `nix build '.#homeConfigurations."ricardo@wsl-legacy".activationPackage'`; `home-manager switch --dry-run --flake "$PWD#$(whoami)@wsl"`.
   - Completion criteria: default activation builds without legacy app links; legacy activation builds with current fallback profile; dry-run shows no auth/runtime ownership.
   - Logical commit message: `refactor: split WSL home-manager modules`.

## Sprint 2: `orca-prime` Dev Shell, Node Boundary

1. Task: add dev shell
   - Goal: provide Orca Prime shell with Node 22 while default profile keeps Node 24.
   - Exact files: `flake.nix`, optional `shells/orca-prime.nix`.
   - Implementation contract: add `devShells.${system}.orca-prime` with exactly Node 22, Python 3, `uv`, `gh`, `jq`, `ripgrep`, `gnumake`, `gcc`, `pkg-config`; set `NPM_CONFIG_PREFIX="$HOME/.local/share/npm"`; prepend `$NPM_CONFIG_PREFIX/bin` to `PATH`; set `PRIME_AGENT_TELEMETRY=0`, `PI_SKIP_VERSION_CHECK=1`, `LAVISH_AXI_TELEMETRY=0`, `LAVISH_AXI_NO_OPEN=1`, `LAVISH_AXI_HOST=127.0.0.1`.
   - Forbidden scope: no global Node downgrade; no Prime/Lavish install; no npm install; no auth/session/cache paths.
   - Verification commands: `nix develop .#orca-prime --command node --version`; `nix develop .#orca-prime --command python3 --version`; `nix develop .#orca-prime --command uv --version`; `nix develop .#orca-prime --command gh --version`; outside shell, `node --version`.
   - Completion criteria: inside shell reports Node 22; outside shell reports Node 24; shell env vars present.
   - Logical commit message: `feat: add orca-prime dev shell`.

## Sprint 3: Prime Policy, Skill Pin, Transitional Tool Installer

1. Task: add Prime policy and settings ownership
   - Goal: manage only reviewed public Prime files.
   - Exact files: `home/.prime/agent/AGENTS.md`, `home/.prime/agent/settings.json`, `modules/home-orca-prime.nix`, `.gitignore`.
   - Implementation contract: link only `~/.prime/agent/AGENTS.md` and `~/.prime/agent/settings.json`; keep public, reviewable content; add `.gitignore` guards for `home/.prime/agent/auth*`, `home/.prime/agent/sessions/`, `home/.prime/agent/cache/`, `home/.prime/agent/downloads/`, `home/.local/share/npm/`, and repo-local Windows staging outputs.
   - Forbidden scope: no whole `~/.prime` ownership; no auth, tokens, sessions, caches, downloads, runtime dirs; no replacement of existing `home/AGENTS.md` unless separately reviewed.
   - Verification commands: `jq empty home/.prime/agent/settings.json`; `home-manager switch --dry-run --flake "$PWD#$(whoami)@wsl"`; secret scan command from `PLAN.md`.
   - Completion criteria: JSON parses; Home Manager owns only approved files; secret scan clean.
   - Logical commit message: `feat: add Prime policy and config`.

2. Task: pin `i-have-adhd` skill
   - Goal: expose only approved skill to Prime.
   - Exact files: `flake.nix`, `flake.lock`, `modules/home-orca-prime.nix`, `README.md`.
   - Implementation contract: add non-flake input `github:ayghri/i-have-adhd/2ed064090711586e0c97a2fbbf15465fe8f1808b`; link `${i-have-adhd}/skills/i-have-adhd` to `~/.prime/agent/skills/i-have-adhd`; document pin.
   - Forbidden scope: no hooks; no plugins; no installers; no vendoring whole upstream repo; no auto-enable unless `~/.prime/agent/settings.json` supports opt-in by name.
   - Verification commands: `nix flake check`; `nix build '.#homeConfigurations."ricardo@wsl".activationPackage'`.
   - Completion criteria: lockfile records exact pin; activation contains exact skill link only.
   - Logical commit message: `feat: add pinned Prime skill`.

3. Task: add transitional pinned tool install script
   - Goal: document reviewed non-reproducible install path until Nix packaging exists.
   - Exact files: `scripts/install-prime-tools.sh`, `README.md`, `.gitignore`.
   - Implementation contract: script runs inside `nix develop .#orca-prime`; Prime source `https://app.primeintellect.ai/prime-agent/install.sh` with version `0.7.2` only after review; npm packages `lavish-axi@0.1.50` and `gh-axi@0.1.30`; npm flags `--ignore-scripts --no-audit --no-fund`; prefix `$HOME/.local/share/npm`; record exact versions, checksums/integrity, audit notes.
   - Forbidden scope: no claim tools are reproducibly Nix-packaged; no installer execution during planning; no committed npm cache/runtime downloads.
   - Verification commands: `bash -n scripts/install-prime-tools.sh`; after approved install only: `nix develop .#orca-prime --command prime-agent --version`; `nix develop .#orca-prime --command lavish-axi --version`; `nix develop .#orca-prime --command gh-axi --version`.
   - Completion criteria: parser passes; approved post-install versions are Prime `0.7.2`, Lavish `0.1.50`, gh-axi `0.1.30`; README states transitional installer boundary.
   - Logical commit message: `feat: add pinned Prime tool installer`.

## Sprint 4: Ubuntu/Windows Bootstrap and Smoke Verification

1. Task: Ubuntu SSH relay bootstrap
   - Goal: prepare WSL host prerequisites for Orca loopback SSH.
   - Exact files: `scripts/ubuntu-bootstrap.sh`, `README.md`.
   - Implementation contract: idempotently install/check `openssh-server`, `build-essential`, `python3`; create/update loopback-only sshd config for `127.0.0.1:2222`; enforce key-only auth, no root login, no password auth, no keyboard-interactive auth, explicit `AuthorizedKeysFile`; safely restart `ssh` under WSL.
   - Forbidden scope: no WSL private-key management; no bind to `0.0.0.0:2222`; no host-mutating run before Gate B.
   - Verification commands: `bash -n scripts/ubuntu-bootstrap.sh`; after Gate B only: `sudo sshd -t`; `ss -ltnp | rg '127\.0\.0\.1:2222'`; `sudo sshd -T -f /etc/ssh/sshd_config | rg '^(passwordauthentication no|kbdinteractiveauthentication no|permitrootlogin no|pubkeyauthentication yes)'`.
   - Completion criteria: parser passes; after approved run, sshd config validates and listens only on loopback.
   - Logical commit message: `feat: add Ubuntu WSL SSH bootstrap`.

2. Task: Windows Orca bootstrap
   - Goal: verify Windows Orca and connect it to Ubuntu WSL by dedicated SSH key.
   - Exact files: `scripts/windows-orca-bootstrap.ps1`, `README.md`.
   - Implementation contract: verify WSL distro name exactly `Ubuntu`; write/verify `%UserProfile%\.wslconfig`; generate key only if absent at `%USERPROFILE%\.ssh\orca-wsl-ed25519`; copy public key to Ubuntu `~/.ssh/authorized_keys` via `wsl.exe -d Ubuntu`; download Orca `1.4.184` from `https://github.com/stablyai/orca/releases/download/v1.4.184/orca-windows-setup.exe`; require SHA256 `7765f7f085d04b7fe662ec664825fedd81427dd586023f945182a46e0a0cf5be`; support `-VerifyOnly`; verify SSH client, WSL reachability, loopback SSH, terminal/node-pty prerequisite path.
   - Forbidden scope: no private key output; no secrets; no auto-rename of WSL distro; no installer run before Gate B; no committed installer binary.
   - Verification commands: `powershell.exe -NoProfile -Command "$errors=$null; [System.Management.Automation.PSParser]::Tokenize((Get-Content .\scripts\windows-orca-bootstrap.ps1 -Raw), [ref]$errors) > $null; if ($errors) { $errors; exit 1 }"`; after Gate B only: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows-orca-bootstrap.ps1 -VerifyOnly`; Orca SSH smoke from `PLAN.md`.
   - Completion criteria: parser passes; `-VerifyOnly` fails closed on wrong distro, checksum mismatch, missing key auth, password auth; no key material or installer binary committed.
   - Logical commit message: `feat: add Windows Orca bootstrap`.

3. Task: validation wrapper and smoke tests
   - Goal: centralize repeatable checks without committing evidence.
   - Exact files: `scripts/validate.sh`, `tests/smoke-orca-prime.sh`.
   - Implementation contract: wrap syntax checks, Nix checks, JSON parse, secret scan, version checks, SSH checks when available; keep evidence out of repo.
   - Forbidden scope: no `.no-mistakes/` commit; no host mutation unless explicitly requested; no secrets in logs.
   - Verification commands: `bash -n scripts/validate.sh`; `bash -n tests/smoke-orca-prime.sh`; `scripts/validate.sh` after implementation.
   - Completion criteria: scripts parse; validation reports actionable pass/fail; no evidence staged.
   - Logical commit message: `test: add validation smoke scripts`.

## Sprint 5: Docs, Full Validation, Migration, PR Handoff

1. Task: README and agent guidance rewrite
   - Goal: make repo docs match Ubuntu WSL + Orca Prime reality.
   - Exact files: `README.md`, `AGENTS.md`.
   - Implementation contract: remove stale Mac/nix-darwin narrative; document Windows Orca `1.4.184`, WSL distro `Ubuntu`, loopback SSH `127.0.0.1:2222`, `nix develop .#orca-prime`, Prime/Lavish/gh-axi pinned installer phase, bootstrap order, secrets boundaries, unmanaged runtime/auth state, legacy fallback profile, and rule forbidding WezTerm/Herdr/Pi in Orca-owned worktrees; update `AGENTS.md` by removing absent `configuration.nix` Homebrew note, retaining `.no-mistakes/` ban, adding Orca/Prime authority and secrets boundaries.
   - Forbidden scope: no unsupported paths or binary names; no claim that Prime/Lavish/gh-axi are reproducibly Nix-packaged; no weakening `.no-mistakes/` rule.
   - Verification commands: `rg -n 'nix-darwin|Homebrew|configuration\.nix|WezTerm|Herdr|Pi|prime-agent|lavish-axi|gh-axi|127\.0\.0\.1:2222|orca-wsl-ed25519' README.md AGENTS.md`.
   - Completion criteria: docs align with implemented files and approved values; stale Mac/default legacy claims gone.
   - Logical commit message: `docs: rewrite README for Orca WSL`.

2. Task: full validation
   - Goal: prove implementation ready for migration.
   - Exact files: repo-wide validation only.
   - Implementation contract: run all available syntax/static/Nix/secret checks; run host checks only after Gate B and where environment supports them.
   - Forbidden scope: no committing `.no-mistakes/`, keys, installers, caches, auth, sessions; no push.
   - Verification commands: `git status --short`; `git diff --check`; all validation commands listed in `PLAN.md`.
   - Completion criteria: all supported checks pass; unsupported Windows GUI/Orca checks clearly documented; `gh auth status` still known unauthenticated unless Ricardo authenticates.
   - Logical commit message: none if checks only; otherwise commit relevant fixes with prior sprint messages.

3. Task: migration rehearsal
   - Goal: prove switch and rollback flow before real handoff.
   - Exact files: none unless docs need correction.
   - Implementation contract: rehearse `home-manager switch --dry-run --flake "$PWD#$(whoami)@wsl"`; document rollback using `home-manager generations`; verify legacy dry-run; do not alter Windows Orca or SSH key state until scripts pass verify/dry mode.
   - Forbidden scope: no destructive rollback; no force push; no main branch changes.
   - Verification commands: `home-manager switch --dry-run --flake "$PWD#$(whoami)@wsl"`; `nix build '.#homeConfigurations."ricardo@wsl-legacy".activationPackage'`; `git status --short`.
   - Completion criteria: migration and rollback steps are executable and documented.
   - Logical commit message: none unless docs corrected.

4. Task: commit stack
   - Goal: produce small independently verified commits.
   - Exact files: all changed planned files.
   - Implementation contract: before each commit run `git status --short` and `git diff --check`; commit logical units only.
   - Forbidden scope: no `.no-mistakes/`, private keys, public/private credential pairs, tokens, `authorized_keys` snapshots, Prime/Lavish auth, sessions, caches, npm/git runtime downloads, Orca installer binaries.
   - Verification commands: `git status --short`; `git diff --check`; relevant sprint checks.
   - Completion criteria: commit stack matches sprint boundaries and each commit is verified.
   - Logical commit message: use sprint task messages above.

5. Task: push and PR handoff
   - Goal: publish feature branch and open PR only after approval.
   - Exact files: `PR.md` if used.
   - Implementation contract: after Gate C, push only `feat/orca-prime-home-manager`; create PR base `main`, head `feat/orca-prime-home-manager`, title `Add Orca Prime WSL Home Manager setup`; if `gh auth status` fails, hand off GitHub web UI path after branch push.
   - Forbidden scope: no push to `main`; no force push; no PR before validation and approval; no push while unauthenticated unless remote auth works by another configured credential.
   - Verification commands: `gh auth status`; `git push -u origin feat/orca-prime-home-manager`; `gh pr create --base main --head feat/orca-prime-home-manager --title "Add Orca Prime WSL Home Manager setup" --body-file PR.md`.
   - Completion criteria: feature branch pushed only after approval; PR created only after auth and approval, or manual PR handoff documented.
   - Logical commit message: none.
