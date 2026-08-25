{ pkgs, lib, i-have-adhd }:
let
  inherit (pkgs) fetchurl fetchgit stdenvNoCC;
  firstmateCommit = "038d0f7ec6ba7238a151722931434dcf06ff37c4";
  firstmateSource = fetchurl {
    url = "https://github.com/kunchenguid/firstmate/archive/${firstmateCommit}.tar.gz";
    hash = "sha256-LFOz/I2vOfWXAVyOmbho2J8gbhalJxlN1WzHSzgu1YA=";
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

  firstmate = stdenvNoCC.mkDerivation {
    pname = "firstmate";
    version = firstmateCommit;
    src = firstmateSource;
    sourceRoot = "firstmate-${firstmateCommit}";
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/firstmate" "$out/bin"
      cp -R ./. "$out/share/firstmate/"
      find "$out/share/firstmate/bin" -type f -name '*.sh' -exec chmod 0755 {} +
      for script in "$out/share/firstmate"/bin/*.sh; do
        [ -f "$script" ] || continue
        ln -s "$script" "$out/bin/$(basename "$script")"
      done
      runHook postInstall
    '';
    meta = {
      description = "Pinned Firstmate Linux tmux/Treehouse orchestration distro";
      homepage = "https://github.com/kunchenguid/firstmate";
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
      mkdir -p "$out/lib/node_modules/lavish-axi" "$out/bin"
      cp -R "${lavishNpmDeps}/node_modules/lavish-axi/." "$out/lib/node_modules/lavish-axi/"
      makeWrapper "${pkgs.nodejs}/bin/node" "$out/bin/lavish-axi" \
        --add-flags "$out/lib/node_modules/lavish-axi/dist/cli.mjs"
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
      mkdir -p "$out/lib/node_modules/gh-axi" "$out/bin"
      cp -R "${ghNpmDeps}/node_modules/gh-axi/." "$out/lib/node_modules/gh-axi/"
      makeWrapper "${pkgs.nodejs}/bin/node" "$out/bin/gh-axi" \
        --add-flags "$out/lib/node_modules/gh-axi/dist/bin/gh-axi.js"
      runHook postInstall
    '';
  };
}
