{ pkgs, lib, i-have-adhd }:
let
  inherit (pkgs) fetchurl stdenvNoCC;
  noMistakesSource = fetchurl {
    url = "https://github.com/kunchenguid/no-mistakes/archive/refs/tags/v1.57.0.tar.gz";
    hash = "sha256-lRkgF8sjAa1ND3WPaXHqIvSavmPgEZFrcci1bqZ5hLs=";
  };
  piCompactionCommit = "8a3de2f3b0c178fdd6f73f2f94172dfc3943e466";
  piCompactionSource = fetchurl {
    url = "https://github.com/kunchenguid/pi-openai-server-compaction/archive/${piCompactionCommit}.tar.gz";
    hash = "sha256-iNwxX81HRuAcUyB7ssI45azzN7PJYXLZ2BYqFh6MwV0=";
  };
  npmDependencyClosure = name:
    let
      lock = builtins.fromJSON (builtins.readFile (builtins.toPath "${toString ./.}/npm/${name}/package-lock.json"));
      entries = lib.mapAttrsToList
        (path: info: {
          inherit path;
          source = fetchurl {
            url = info.resolved;
            hash = info.integrity;
          };
        })
        (lib.filterAttrs (path: _: path != "") lock.packages);
    in
    stdenvNoCC.mkDerivation {
      pname = "${name}-npm-deps";
      version = "locked";
      dontUnpack = true;
      nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
      buildCommand = ''
        mkdir -p "$out"
        ${lib.concatMapStringsSep "\n" (entry: ''
          extract_dir="$TMPDIR/npm-extract-${lib.replaceStrings [ "/" ] [ "-" ] entry.path}"
          rm -rf "$extract_dir"
          mkdir -p "$extract_dir"
          tar -xzf "${entry.source}" -C "$extract_dir"
          mkdir -p "$out/${entry.path}"
          cp -R "$extract_dir/package/." "$out/${entry.path}/"
        '') entries}
      '';
    };

  lavishNpmDeps = npmDependencyClosure "lavish-axi";
  ghNpmDeps = npmDependencyClosure "gh-axi";
  quotaNpmDeps = npmDependencyClosure "quota-axi";
  tasksNpmDeps = npmDependencyClosure "tasks-axi";
  chromeDevtoolsNpmDeps = npmDependencyClosure "chrome-devtools-axi";
  piCompactionNpmDeps = npmDependencyClosure "pi-openai-server-compaction";
in
{
  codebase-memory-mcp = stdenvNoCC.mkDerivation {
    pname = "codebase-memory-mcp";
    version = "0.10.8";
    src = fetchurl {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v0.10.8/codebase-memory-mcp-linux-amd64-portable.tar.gz";
      hash = "sha256-bu9JZSvAx4IPQxFBJQRNQL9/TZfBGyWS9rD2owdwIyU=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
    installPhase = ''
      runHook preInstall
      archive_dir="$TMPDIR/codebase-memory-extracted"
      mkdir -p "$archive_dir"
      tar -xzf "$src" -C "$archive_dir"
      install -Dm755 "$archive_dir/codebase-memory-mcp" "$out/bin/codebase-memory-mcp"
      runHook postInstall
    '';
    meta = {
      description = "Local Codebase Memory MCP server";
      platforms = [ "x86_64-linux" ];
    };
  };

  no-mistakes = stdenvNoCC.mkDerivation {
    pname = "no-mistakes";
    version = "1.57.0";
    src = fetchurl {
      url = "https://github.com/kunchenguid/no-mistakes/releases/download/v1.57.0/no-mistakes-v1.57.0-linux-amd64.tar.gz";
      hash = "sha256-EUXnvUGgEwE+rkuqUz0kEyLSDZF//vcyWVRg3b84W4Q=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
    installPhase = ''
      runHook preInstall
      archive_dir="$TMPDIR/no-mistakes-extracted"
      mkdir -p "$archive_dir"
      tar -xzf "$src" -C "$archive_dir"
      install -Dm755 "$archive_dir/no-mistakes" "$out/bin/no-mistakes"
      runHook postInstall
    '';
    meta = {
      description = "Deterministic no-mistakes safety gate CLI";
      platforms = [ "x86_64-linux" ];
    };
  };

  no-mistakes-skill = stdenvNoCC.mkDerivation {
    pname = "no-mistakes-skill";
    version = "1.57.0";
    src = noMistakesSource;
    sourceRoot = "no-mistakes-1.57.0";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/skills/no-mistakes"
      cp -R ./skills/no-mistakes/. "$out/share/skills/no-mistakes/"
      runHook postInstall
    '';
    meta = {
      description = "Pinned no-mistakes agent skill";
    };
  };

  treehouse = stdenvNoCC.mkDerivation {
    pname = "treehouse";
    version = "2.0.1";
    src = fetchurl {
      url = "https://github.com/kunchenguid/treehouse/releases/download/v2.0.1/treehouse-v2.0.1-linux-amd64.tar.gz";
      hash = "sha256-HVoydRq5IWcBA/0gHdsrkbRzOMsTl29FZCuCfPiXavI=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
    installPhase = ''
      runHook preInstall
      archive_dir="$TMPDIR/treehouse-extracted"
      mkdir -p "$archive_dir"
      tar -xzf "$src" -C "$archive_dir"
      install -Dm755 "$archive_dir/treehouse" "$out/bin/treehouse"
      runHook postInstall
    '';
    meta = {
      description = "Firstmate Linux Treehouse worktree provider";
      platforms = [ "x86_64-linux" ];
    };
  };

  caveman = stdenvNoCC.mkDerivation {
    pname = "caveman-skill";
    version = "git";
    src = ../home/.agents/skills/caveman;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/skills/caveman"
      cp -R ./. "$out/share/skills/caveman/"
      runHook postInstall
    '';
  };

  i-have-adhd-skill = stdenvNoCC.mkDerivation {
    pname = "i-have-adhd-skill";
    version = "2ed064090711586e0c97a2fbbf15465fe8f1808b";
    src = i-have-adhd;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/skills/i-have-adhd"
      cp -R ./skills/i-have-adhd/. "$out/share/skills/i-have-adhd/"
      runHook postInstall
    '';
  };

  lavish-axi = stdenvNoCC.mkDerivation {
    pname = "lavish-axi";
    version = "0.1.50";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/node_modules/lavish-axi-runtime" "$out/bin"
      cp -R "${lavishNpmDeps}/node_modules" "$out/lib/node_modules/lavish-axi-runtime/"
      makeWrapper "${pkgs.nodejs_24}/bin/node" "$out/bin/lavish-axi" \
        --add-flags "$out/lib/node_modules/lavish-axi-runtime/node_modules/lavish-axi/dist/cli.mjs"
      runHook postInstall
    '';
  };

  gh-axi = stdenvNoCC.mkDerivation {
    pname = "gh-axi";
    version = "0.1.30";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/node_modules/gh-axi-runtime" "$out/bin"
      cp -R "${ghNpmDeps}/node_modules" "$out/lib/node_modules/gh-axi-runtime/"
      makeWrapper "${pkgs.nodejs_24}/bin/node" "$out/bin/gh-axi" \
        --add-flags "$out/lib/node_modules/gh-axi-runtime/node_modules/gh-axi/dist/bin/gh-axi.js"
      runHook postInstall
    '';
  };

  quota-axi = stdenvNoCC.mkDerivation {
    pname = "quota-axi";
    version = "0.1.32";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/node_modules/quota-axi-runtime" "$out/bin"
      cp -R "${quotaNpmDeps}/node_modules" "$out/lib/node_modules/quota-axi-runtime/"
      makeWrapper "${pkgs.nodejs_24}/bin/node" "$out/bin/quota-axi" \
        --add-flags "$out/lib/node_modules/quota-axi-runtime/node_modules/quota-axi/dist/bin/quota-axi.js"
      runHook postInstall
    '';
  };

  tasks-axi = stdenvNoCC.mkDerivation {
    pname = "tasks-axi";
    version = "0.2.5";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/node_modules/tasks-axi-runtime" "$out/bin"
      cp -R "${tasksNpmDeps}/node_modules" "$out/lib/node_modules/tasks-axi-runtime/"
      makeWrapper "${pkgs.nodejs_24}/bin/node" "$out/bin/tasks-axi" \
        --add-flags "$out/lib/node_modules/tasks-axi-runtime/node_modules/tasks-axi/dist/bin/tasks-axi.js"
      runHook postInstall
    '';
  };

  chrome-devtools-axi = stdenvNoCC.mkDerivation {
    pname = "chrome-devtools-axi";
    version = "0.1.31";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/node_modules/chrome-devtools-axi-runtime" "$out/bin"
      cp -R "${chromeDevtoolsNpmDeps}/node_modules" "$out/lib/node_modules/chrome-devtools-axi-runtime/"
      makeWrapper "${pkgs.nodejs_24}/bin/node" "$out/bin/chrome-devtools-axi" \
        --add-flags "$out/lib/node_modules/chrome-devtools-axi-runtime/node_modules/chrome-devtools-axi/dist/bin/chrome-devtools-axi.js"
      runHook postInstall
    '';
  };

  pi-openai-server-compaction = stdenvNoCC.mkDerivation {
    pname = "pi-openai-server-compaction";
    version = piCompactionCommit;
    src = piCompactionSource;
    sourceRoot = "pi-openai-server-compaction-${piCompactionCommit}";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R ./. "$out/"
      mkdir -p "$out/node_modules"
      cp -R "${piCompactionNpmDeps}/node_modules/." "$out/node_modules/"
      runHook postInstall
    '';
    meta = {
      description = "Pi extension for OpenAI server-side compaction";
      homepage = "https://github.com/kunchenguid/pi-openai-server-compaction";
    };
  };
}
