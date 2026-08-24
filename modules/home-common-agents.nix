{ config, i-have-adhd, ... }:

let
  home = config.home.homeDirectory;
  mutableSkill = name:
    config.lib.file.mkOutOfStoreSymlink "${home}/.agents/skills/${name}";
in
{
  # One tracked AGENTS.md is shared by AGY, Pi, and Prime.
  home.file.".pi/agent/AGENTS.md".source = ../AGENTS.md;
  home.file.".gemini/GEMINI.md".source = ../AGENTS.md;
  home.file.".prime/agent/AGENTS.md".source = ../AGENTS.md;

  # Authored skills are pinned or tracked and exposed to all three harnesses.
  home.file.".agents/skills/caveman".source =
    ../home/.agents/skills/caveman;
  home.file.".agents/skills/i-have-adhd".source =
    "${i-have-adhd}/skills/i-have-adhd";
  home.file.".gemini/antigravity-cli/skills/caveman".source =
    ../home/.agents/skills/caveman;
  home.file.".gemini/antigravity-cli/skills/i-have-adhd".source =
    "${i-have-adhd}/skills/i-have-adhd";
  home.file.".prime/agent/skills/caveman".source =
    ../home/.agents/skills/caveman;
  home.file.".prime/agent/skills/i-have-adhd".source =
    "${i-have-adhd}/skills/i-have-adhd";

  # Lavish and gh-axi publish mutable skills during the reviewed regular-shell
  # installer. Client-specific roots point at the shared user-global copies.
  home.file.".gemini/antigravity-cli/skills/lavish".source = mutableSkill "lavish";
  home.file.".gemini/antigravity-cli/skills/gh-axi".source = mutableSkill "gh-axi";
  home.file.".prime/agent/skills/lavish".source = mutableSkill "lavish";
  home.file.".prime/agent/skills/gh-axi".source = mutableSkill "gh-axi";

  # Pi reads ~/.agents/skills directly. AGY and Prime use their client roots
  # above, while all three invoke the same user-owned binaries on PATH.

  # Pi's adapter reads the shared user-global MCP file. AGY and Prime use their
  # own documented profile paths with the same server policy and binary.
  home.file.".config/mcp/mcp.json".source =
    ../home/.config/mcp/mcp.json;
  home.file.".gemini/config/mcp_config.json".source =
    ../home/.gemini/config/mcp_config.json;
  home.file.".gemini/antigravity-cli/mcp_config.json".source =
    ../home/.gemini/config/mcp_config.json;
}
