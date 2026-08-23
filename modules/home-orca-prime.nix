{ i-have-adhd, ... }:
{
  home.sessionVariables = {
    CBM_ALLOWED_ROOT = "/home/ricardo/src";
    CBM_CACHE_DIR = "/home/ricardo/.cache/codebase-memory-mcp";
    CBM_DIAGNOSTICS = "0";
  };

  # Manage exact reviewed policy files only. Prime auth, sessions, daemon
  # state, caches, downloads, and other runtime state remain mutable/local.
  home.file.".prime/agent/AGENTS.md".source =
    ../home/.prime/agent/AGENTS.md;

  home.file.".prime/agent/settings.json".source =
    ../home/.prime/agent/settings.json;

  # Link only the reviewed skill directory from the pinned non-flake input.
  # Hooks, extensions, plugins, and installers from that repository are absent.
  home.file.".prime/agent/skills/i-have-adhd".source =
    "${i-have-adhd}/skills/i-have-adhd";
}
