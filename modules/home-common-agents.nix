{ config, agentPackages, ... }:

let
  home = config.home.homeDirectory;
in
{
  # One tracked AGENTS.md is shared by AGY, Pi, and Prime.
  home.file.".pi/agent/AGENTS.md".source = ../AGENTS.md;
  home.file.".gemini/GEMINI.md".source = ../AGENTS.md;
  home.file.".prime/agent/AGENTS.md".source = ../AGENTS.md;

  # Authored skills are Nix packages and exposed to all three harnesses.
  home.file.".agents/skills/caveman".source =
    "${agentPackages.caveman}/share/skills/caveman";
  home.file.".agents/skills/i-have-adhd".source =
    "${agentPackages.i-have-adhd-skill}/share/skills/i-have-adhd";
  home.file.".gemini/antigravity-cli/skills/caveman".source =
    "${agentPackages.caveman}/share/skills/caveman";
  home.file.".gemini/antigravity-cli/skills/i-have-adhd".source =
    "${agentPackages.i-have-adhd-skill}/share/skills/i-have-adhd";
  home.file.".prime/agent/skills/caveman".source =
    "${agentPackages.caveman}/share/skills/caveman";
  home.file.".prime/agent/skills/i-have-adhd".source =
    "${agentPackages.i-have-adhd-skill}/share/skills/i-have-adhd";

  home.file.".agents/skills/lavish".source =
    "${agentPackages.lavish-axi}/lib/node_modules/lavish-axi/skills/lavish";
  home.file.".agents/skills/gh-axi".source =
    "${agentPackages.gh-axi}/lib/node_modules/gh-axi/skills/gh-axi";
  home.file.".gemini/antigravity-cli/skills/lavish".source =
    "${agentPackages.lavish-axi}/lib/node_modules/lavish-axi/skills/lavish";
  home.file.".gemini/antigravity-cli/skills/gh-axi".source =
    "${agentPackages.gh-axi}/lib/node_modules/gh-axi/skills/gh-axi";
  home.file.".prime/agent/skills/lavish".source =
    "${agentPackages.lavish-axi}/lib/node_modules/lavish-axi/skills/lavish";
  home.file.".prime/agent/skills/gh-axi".source =
    "${agentPackages.gh-axi}/lib/node_modules/gh-axi/skills/gh-axi";

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
