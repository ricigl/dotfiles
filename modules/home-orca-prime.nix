{ ... }:
{
  home.sessionVariables = {
    CBM_ALLOWED_ROOT = "/home/ricardo/src";
    CBM_CACHE_DIR = "/home/ricardo/.cache/codebase-memory-mcp";
    CBM_DIAGNOSTICS = "0";
  };

  # Prime settings are reviewed and public. Auth, sessions, caches, downloads,
  # and other runtime state remain mutable and local.
  home.file.".prime/agent/settings.json".source =
    ../home/.prime/agent/settings.json;
}
