# Sprint Plan: Herdr Agents Nix Packaging

The unified Home Manager migration is implemented on `orca-agents-nix`. The Herdr thin-client variant is developed on `herdr-agents-nix`. This file retains earlier Orca sprint history and records the current packaging boundary and validation gates.

Hard gates:

- Gate A: explicit approval before broad source edits; the current Nix packaging implementation is approved.
- Gate B: explicit approval before any host-mutating bootstrap run on Ubuntu or Windows.
- Gate C: explicit approval before push or PR. Ricardo explicitly approved the `orca-agents-nix` push.

Constraints:

- Branch is `herdr-agents-nix`, based on `orca-agents-nix`; `main` and the previous rollback branch remain unchanged.
- `origin/main` remains unchanged backup.
- Keep global Node 24 in default Home Manager profile.
- `orca-prime` shell is optional and resolves Node 22 for validation only.
- Prime, Pi, and AGY launch from the regular Home Manager shell.
- Root `AGENTS.md` is the single shared policy source for all three harnesses.
- Firstmate root is `~/firstmate`; project and Treehouse worktree root is `~/firstmate/projects`.
- Firstmate owns Linux Treehouse worktrees; Windows Herdr connects over SSH without worktree lifecycle operations.
- Linux Herdr is a pinned Home Manager package in the regular profile. Glow is also Home Manager-managed. `agy`, `pi`, `prime-agent`, Herdr integrations, the global Herdr skill, Hunk, the Herdr Hunk plugin, the Herdr file-viewer plugin, Firstmate (cloned to `~/firstmate`), and Google Chrome (installed via apt from the official Debian package) are installed by scripts. Lavish, gh-axi, Codebase Memory, no-mistakes, Treehouse, Caveman, and `i-have-adhd` remain Nix/Home Manager packages.
- Windows SSH key: `%USERPROFILE%\.ssh\orca-wsl-ed25519`.
- `gh auth status` currently fails because this environment is unauthenticated.
- This host has no native `nix` executable. Use an available pinned container validator only if its daemon is running; do not claim target activation or Herdr runtime acceptance until Ricardo verifies them in Ubuntu WSL.

The earlier sprint sections document the already-landed baseline. Sprint 6 below supersedes conflicting Prime-policy, Prime-shell, and Orca-worktree assumptions. Sprint 7 below defines the Herdr thin-client variant. Sprint 8 defines the concise AGY terminal Q&A workflow.

## Sprint 8: AGY Concise Terminal Q&A Workflow

1. Task: add concise AGY Q&A CLI and Zsh `?` alias
   - Goal: provide direct terminal answers through AGY without browser automation or Google account state.
   - Exact files: `scripts/agy-query.sh`, `modules/home-base.nix`, `tests/test-agy-query.sh`, `scripts/validate.sh`, `README.md`, `PLAN.md`, `SPRINT_PLAN.md`.
   - Implementation contract: add user-owned executable `scripts/agy-query.sh`; expose it as Zsh `?`; join question arguments safely; invoke `agy --print --model gemini-3.7-flash-low --effort low --output-format text`; instruct AGY to be short, concise, direct, and action-oriented for programming questions; allow tools only when a web search is necessary and prohibit all other tools; print the model response to the terminal.
   - Forbidden scope: no `--dangerously-skip-permissions` for the Q&A wrapper; no browser automation, search profile, cookie, or account-auth state; no network or real AGY execution during tests; no credentials or secrets; no shell injection.
   - Verification commands: `bash -n scripts/agy-query.sh`; `bash -n tests/test-agy-query.sh`; `./tests/test-agy-query.sh`; `./scripts/validate.sh`; `git diff --check`.
   - Completion criteria: wrapper and alias contracts pass; fake-AGY behavior tests pass; aggregate validator passes; no stale browser-search files or references remain.
   - Logical commit message: `feat: replace google search alias with agy qna`.

## Sprint 7: Herdr Thin Client and Linux Home-Agent Server

1. Task: move Herdr into the regular Home Manager profile
   - Goal: make the WSL regular home-agent shell the Herdr server runtime.
   - Exact files: `flake.nix`, `flake.lock`, `modules/home-base.nix`, `modules/home-legacy-agents.nix`, `home/.config/herdr`, `README.md`, `PLAN.md`.
   - Implementation contract: update the pinned Herdr input from `v0.7.5` to stable `v0.8.2`; add the package and authored config link to the regular profile; remove the direct Herdr package/config declaration from the legacy module; preserve user-owned Herdr sessions and caches outside Git.
   - Forbidden scope: no host service changes; no Herdr daemon start during validation; no auth/session/cache ownership; no Windows Orca installation.
   - Verification commands: `nix flake check`; `nix build '.#homeConfigurations."ricardo@wsl".activationPackage'`; `nix build '.#homeConfigurations."ricardo@wsl-legacy".activationPackage'`; `herdr --version` after target activation.
   - Completion criteria: regular profile contains Herdr `0.8.2`; legacy module has no direct Herdr declaration; both profiles evaluate.
   - Logical commit message: `feat: move herdr into regular home profile`.

2. Task: replace Windows Orca bootstrap with Herdr SSH bootstrap
   - Goal: install the Windows Herdr thin client and preserve the existing loopback SSH transport.
   - Exact files: `scripts/windows-herdr-bootstrap.ps1`, `scripts/ubuntu-bootstrap.sh`, `README.md`, `AGENTS.md`, `scripts/validate.sh`, `tests/smoke-herdr-agents.sh`.
   - Implementation contract: rename the Windows script; remove Orca download/install/checksum logic; add `-InstallHerdr` behind `-Apply`, verify the reviewed `https://herdr.dev/install.ps1` SHA-256 `3415ea0bc562cad003afcc70ac9916b81cde043c4c26087f05255ae7807d1ba7`, and invoke stable-channel installation. Keep WSL version checks, `.wslconfig` preservation, existing dedicated SSH key compatibility, `authorized_keys` handling, `sshd` reachability, `127.0.0.1:2222`, key-only auth, and native build checks.
   - Forbidden scope: no `irm | iex` without installer verification; no Orca installer or executable; no public SSH binding; no password/root/keyboard-interactive auth; no key output.
   - Verification commands: PowerShell parser; `bash -n` for shell scripts; `./scripts/ubuntu-bootstrap.sh --verify-only` and Windows `-VerifyOnly` only on the target host after approval.
   - Completion criteria: Windows script contains no Orca installer path; Herdr install is explicit; SSH configuration remains loopback-only and key-only; the configured `herdr` function uses the `wsl-herdr` SSH target.
   - Logical commit message: `feat: replace windows orca with herdr client`.

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
   - Implementation contract: keep `homeConfigurations."${user}@wsl"` as default; add `homeConfigurations."${user}@wsl-legacy"`; move Zsh, Starship, Git defaults, CLI utilities, Neovim link, ABNT2 support, global Node 24, and `rebuild` alias into base; keep WezTerm/Herdr/Pi authored config/package links in legacy while exposing the default-profile Pi CLI through the separate user-owned Phase 8C installer; keep `home.stateVersion = "24.11"`.
   - Forbidden scope: no WezTerm or Herdr in default Orca lane; no Pi worktree management; no personal Git identity; no `cc = "claude --dangerously-skip-permissions"`; no `co = "codex --ask-for-approval never --sandbox workspace-write"` or equivalent full-auto alias; no `homebrew.onActivation.cleanup` changes.
   - Verification commands: `nix flake check`; `nix build '.#homeConfigurations."ricardo@wsl".activationPackage'`; `nix build '.#homeConfigurations."ricardo@wsl-legacy".activationPackage'`; `home-manager switch --dry-run --flake "$PWD#$(whoami)@wsl"`.
   - Completion criteria: default activation builds without legacy app links; legacy activation builds with current fallback profile; dry-run shows no auth/runtime ownership.
   - Logical commit message: `refactor: split WSL home-manager modules`.

## Sprint 2: `orca-prime` Dev Shell, Node Boundary

1. Task: add dev shell
   - Goal: provide Orca Prime shell with Node 22 while default profile keeps Node 24.
   - Exact files: `flake.nix`, optional `shells/orca-prime.nix`.
   - Implementation contract: add `devShells.${system}.orca-prime` with exactly Node 22, Python 3, `uv`, `gh`, `jq`, `ripgrep`, `gnumake`, `gcc`, `pkg-config`; set `NPM_CONFIG_PREFIX="$HOME/.local/share/npm"`; prepend `$HOME/.local/bin` and `$NPM_CONFIG_PREFIX/bin` to `PATH`; set `PRIME_AGENT_TELEMETRY=0`, `PI_SKIP_VERSION_CHECK=1`, `LAVISH_AXI_TELEMETRY=0`, `LAVISH_AXI_NO_OPEN=1`, `LAVISH_AXI_HOST=127.0.0.1`, `CBM_ALLOWED_ROOT=/home/ricardo`, `CBM_CACHE_DIR=/home/ricardo/.cache/codebase-memory-mcp`, and `CBM_DIAGNOSTICS=0`.
   - Forbidden scope: no global Node downgrade; no Prime/Lavish install; no npm install; no auth/session/cache paths.
   - Verification commands: `nix develop .#orca-prime --command node --version`; `nix develop .#orca-prime --command python3 --version`; `nix develop .#orca-prime --command uv --version`; `nix develop .#orca-prime --command gh --version`; outside shell, `node --version`.
   - Completion criteria: inside shell reports Node 22; outside shell reports Node 24; shell env vars present.
   - Logical commit message: `feat: add orca-prime dev shell`.

## Sprint 3: Prime Policy, Skill Pin, Transitional Tool Installer

1. Task: add Prime policy and settings ownership
   - Goal: manage only reviewed public Prime files.
   - Exact files: `home/.prime/agent/AGENTS.md`, `home/.prime/agent/settings.json`, `modules/home-orca-prime.nix`, `.gitignore`.
   - Implementation contract: link only `~/.prime/agent/AGENTS.md` and `~/.prime/agent/settings.json`; keep public, reviewable content; add `.gitignore` guards for `home/.prime/agent/auth*`, `home/.prime/agent/sessions/`, `home/.prime/agent/cache/`, `home/.prime/agent/downloads/`, `home/.local/share/npm/`, `.codebase-memory/`, `home/.cache/codebase-memory-mcp/`, and repo-local Windows staging outputs.
   - Forbidden scope: no whole `~/.prime` ownership; no auth, tokens, sessions, caches, downloads, runtime dirs; no merging Prime policy into the shared root `AGENTS.md`.
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
   - Implementation contract: historical baseline only. Sprint 6 moves this installer to the regular Home Manager shell; retain the same Prime version, npm pins, integrity checks, prefix, and no-runtime-state policy.
   - Forbidden scope: no claim tools are reproducibly Nix-packaged; no installer execution during planning; no committed npm cache/runtime downloads.
   - Verification commands: `bash -n scripts/install-prime-tools.sh`; after approved install only: `nix develop .#orca-prime --command prime-agent --version`; `nix develop .#orca-prime --command lavish-axi --version`; `nix develop .#orca-prime --command gh-axi --version`.
   - Completion criteria: parser passes; approved post-install versions are Prime `0.8.0`, Lavish `0.1.50`, gh-axi `0.1.30`; README states transitional installer boundary.
   - Logical commit message: `feat: add pinned Prime tool installer`.

4. Task: add Codebase Memory MCP integration
   - Goal: configure Prime 0.8.0 native stdio MCP for local code memory without committing runtime graph/cache state.
   - Exact files: `home/.prime/agent/settings.json`, `modules/home-orca-prime.nix`, `flake.nix`, `scripts/install-codebase-memory.sh`, `scripts/validate.sh`, `tests/smoke-orca-prime.sh`, `README.md`, `.gitignore`.
   - Implementation contract: add `mcpServers.codebase_memory` with type `stdio`, command `/home/ricardo/.local/bin/codebase-memory-mcp`, cwd `/home/ricardo/src`, `startupTimeoutMs` 30000, `callTimeoutMs` 120000, env references for `CBM_ALLOWED_ROOT`, `CBM_CACHE_DIR`, `CBM_DIAGNOSTICS`, and `disabledTools` for `delete_project`, `manage_adr`, `ingest_traces`; add public env policy; add installer for Codebase Memory MCP `0.10.8` using exact release URL and SHA256 `6eef49652bc0c7820f43114125044d40bf7f4d97c11b2592f6b0f6a307702325`; document manual indexing/usage, approved `auto_index=true` and `auto_watch=true`, no UI startup, local-only boundaries, rollback, and uninstall.
   - Forbidden scope: no host bootstrap/apply; no npm or mutable latest refs; no committed `.codebase-memory`, cache, downloaded archive, graph artifact, auth, sessions, or target-machine software install.
   - Verification commands: `bash -n scripts/install-codebase-memory.sh`; `jq empty home/.prime/agent/settings.json`; `git diff --check`; after explicit install only: `nix develop .#orca-prime --command codebase-memory-mcp --version`.
   - Completion criteria: parser checks pass; settings JSON parses; Prime config leaves indexing/read/query available while mutating/high-risk tools are disabled; README and plans describe install/use/rollback.
   - Logical commit message: `feat: add Codebase Memory MCP config`.

5. Task: add Prime maintenance utility
   - Goal: inspect and safely clean Prime agents and saved sessions without exposing session contents.
   - Exact files: `scripts/prime-maintenance.py`, `modules/home-base.nix`, `scripts/validate.sh`, `tests/smoke-orca-prime.sh`, `tests/test-prime-maintenance.sh`, `README.md`.
   - Implementation contract: list agents through `prime-agent list --all --json`; stop one with `stop`; stop all with confirmed `shutdown --force`; parse only session metadata; use trash/gio before permanent deletion; enforce session-directory containment and active-session refusal; support interactive and explicit subcommands, including `clean-unnamed` for stopping all agents and deleting only unnamed sessions while preserving named sessions.
   - Forbidden scope: no real agent/session lifecycle operations during implementation tests; no prompt/transcript output; no unconfirmed destructive action; no recursive deletion of Prime state; no committed session state.
   - Verification commands: `python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("scripts/prime-maintenance.py").read_text())'`; `bash -n tests/test-prime-maintenance.sh`; `tests/test-prime-maintenance.sh`; `git diff --check`.
   - Completion criteria: help, listing, redaction, containment, active-session refusal, unnamed-session filtering, and confirmation tests pass; Home Manager exposes `prime-maintenance`.
   - Logical commit message: `feat: add Prime maintenance utility`.

6. Task: add no-mistakes repository integration
   - Goal: install a pinned local gate CLI and document safe manual activation without changing Git remotes automatically.
   - Exact files: `.no-mistakes.yaml`, `scripts/install-no-mistakes.sh`, `modules/home-base.nix`, `flake.nix`, `scripts/validate.sh`, `tests/smoke-orca-prime.sh`, `README.md`, `PLAN.md`, `.gitignore`.
   - Implementation contract: pin no-mistakes `1.57.0` Linux x86_64 with SHA256 `1145e7bd41a013013eae4baa533d241322d20d917ffef732595460ddbf385b84`; install under `~/.no-mistakes/bin` and link from `~/.local/bin`; set `NO_MISTAKES_TELEMETRY=0` and `NO_MISTAKES_NO_UPDATE_CHECK=1`; configure targeted shell and Prime maintenance checks with `test.evidence.store_in_repo=false`; leave `allow_repo_commands=false`.
   - Forbidden scope: no `no-mistakes init`; no remote mutation; no daemon start or validation gate during installation; no committed `.no-mistakes/` state, credentials, logs, worktrees, databases, or evidence.
   - Verification commands: `bash -n scripts/install-no-mistakes.sh`; disposable checksum-verified install and `--version`; `git diff --check`; target Ubuntu smoke test after explicit installation.
   - Completion criteria: pinned binary installs without root; telemetry and update checks are disabled; repository policy is reviewable; evidence remains local; manual activation steps are documented.
   - Logical commit message: `feat: add no-mistakes repository integration`.

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
   - Implementation contract: remove stale Mac/nix-darwin narrative; document Windows Orca `1.4.184`, WSL distro `Ubuntu`, loopback SSH `127.0.0.1:2222`, `nix develop .#orca-prime`, Prime/Lavish/gh-axi pinned installer phase, AGY/Pi regular Home Manager-shell transitional installer phase, one shared AGY/Pi `AGENTS.md`, shared Caveman skill, Pi MCP adapter, Codebase Memory MCP `0.10.8` for AGY/Pi/Prime, bootstrap order, secrets/cache boundaries, unmanaged runtime/auth/index state, legacy fallback profile, and rule forbidding WezTerm/Herdr/Pi in Orca-owned worktrees; update `AGENTS.md` by removing absent `configuration.nix` Homebrew note, retaining `.no-mistakes/` ban, adding Orca/Prime authority and secrets boundaries.
   - Forbidden scope: no unsupported paths or binary names; no claim that Prime/Lavish/gh-axi are reproducibly Nix-packaged; no weakening `.no-mistakes/` rule.
   - Verification commands: `rg -n 'nix-darwin|Homebrew|configuration\.nix|WezTerm|Herdr|Pi|prime-agent|lavish-axi|gh-axi|127\.0\.0\.1:2222|orca-wsl-ed25519' README.md AGENTS.md`.
   - Completion criteria: docs align with implemented files and approved values; stale Mac/default legacy claims gone.
   - Logical commit message: `docs: rewrite README for Orca WSL`.

2. Task: full validation
   - Goal: prove implementation ready for migration.
   - Exact files: repo-wide validation only.
   - Implementation contract: run all available syntax/static/Nix/secret checks; run host checks only after Gate B and where environment supports them.
   - Forbidden scope: no committing `.no-mistakes/`, keys, installers, caches, auth, sessions, `.codebase-memory`, or graph artifacts; no push.
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
   - Forbidden scope: no `.no-mistakes/`, private keys, public/private credential pairs, tokens, `authorized_keys` snapshots, Prime/Lavish auth, sessions, caches, Codebase Memory graph/index artifacts, npm/git runtime downloads, Orca installer binaries.
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

## Sprint 6: Unified Home Manager Agent Runtime Migration

Planning status: architecture decisions approved by Ricardo; implementation remains gated on explicit coding approval after this plan review.

1. Move all three harnesses into the regular Home Manager shell.
   - Keep Node 24 and the normal Zsh/Starship/Neovim/UX profile as the daily runtime.
   - Make `prime` call the user-installed `prime-agent` directly without entering `nix develop`.
   - Persist the npm global bin directory in PATH for Prime, Lavish, and gh-axi.
   - Keep `.#orca-prime` only as an optional Node 22/build-validation shell.

2. Consolidate common policy and skills.
   - Merge Prime safety and Orca worktree rules into root `AGENTS.md`.
   - Link that source to Pi, AGY, and Prime.
   - Expose Caveman and pinned `i-have-adhd` to all three clients through supported skill roots.
   - Keep Prime settings and client-specific MCP schemas separate from mutable auth/session state.

3. Rebase reviewed installers on the regular-shell boundary.
   - Remove the `IN_NIX_SHELL` requirement from Prime and Codebase Memory installers.
   - Keep checksum/integrity pins, telemetry settings, user-owned prefixes, and no-root behavior.
   - Add one explicit regular-shell installation/verification sequence without silently starting daemons or mutating remotes.

4. Move Firstmate and establish Linux worktree ownership.
   - Install Firstmate under `~/firstmate` and use `~/firstmate/projects` for project roots and Treehouse-managed crew worktrees.
   - Use Firstmate's reviewed Linux `tmux`/Treehouse backend; do not select its pinned macOS-only `orca` backend.
   - Orca connects over SSH and may access selected Firstmate worktrees, but cannot create, move, remove, or prune them.
   - Verify the required Treehouse dependency and Firstmate backend from WSL before enabling crew dispatch.
   - Verify Orca SSH access to the shared project root and at least one safe read-only project operation.

5. Validate and migrate safely.
   - Build both Home Manager profiles and the optional dev shell.
   - Run regular-shell command, policy, skill, MCP, and telemetry smoke checks.
   - Run direct `agy`, `pi`, and `prime` version/help checks from fresh shells.
   - Run bounded read-only Codebase Memory calls through each harness.
   - Run WSL SSH and Orca terminal acceptance before removing old runtime assumptions.

Logical commit groups:

- `docs: plan unified Home Manager agent runtime`
- `refactor: run Prime and shared tools from Home Manager`
- `feat: share policy skills and MCP across three harnesses`
- `feat: place Firstmate projects under WSL home`
- `test: validate unified agent runtime and Orca access`
