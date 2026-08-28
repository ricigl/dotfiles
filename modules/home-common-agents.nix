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
  home.file.".agents/skills/no-mistakes".source =
    "${agentPackages.no-mistakes-skill}/share/skills/no-mistakes";
  home.file.".agents/skills/quota-axi".source =
    "${agentPackages.quota-axi}/lib/node_modules/quota-axi/skills/quota-axi";
  home.file.".agents/skills/tasks-axi".source =
    "${agentPackages.tasks-axi}/lib/node_modules/tasks-axi/skills/tasks-axi";
  home.file.".agents/skills/chrome-devtools-axi".source =
    "${agentPackages.chrome-devtools-axi}/lib/node_modules/chrome-devtools-axi/skills/chrome-devtools-axi";
  home.file.".gemini/antigravity-cli/skills/lavish".source =
    "${agentPackages.lavish-axi}/lib/node_modules/lavish-axi/skills/lavish";
  home.file.".gemini/antigravity-cli/skills/gh-axi".source =
    "${agentPackages.gh-axi}/lib/node_modules/gh-axi/skills/gh-axi";
  home.file.".gemini/antigravity-cli/skills/no-mistakes".source =
    "${agentPackages.no-mistakes-skill}/share/skills/no-mistakes";
  home.file.".gemini/antigravity-cli/skills/quota-axi".source =
    "${agentPackages.quota-axi}/lib/node_modules/quota-axi/skills/quota-axi";
  home.file.".gemini/antigravity-cli/skills/tasks-axi".source =
    "${agentPackages.tasks-axi}/lib/node_modules/tasks-axi/skills/tasks-axi";
  home.file.".gemini/antigravity-cli/skills/chrome-devtools-axi".source =
    "${agentPackages.chrome-devtools-axi}/lib/node_modules/chrome-devtools-axi/skills/chrome-devtools-axi";
  home.file.".prime/agent/skills/lavish".source =
    "${agentPackages.lavish-axi}/lib/node_modules/lavish-axi/skills/lavish";
  home.file.".prime/agent/skills/gh-axi".source =
    "${agentPackages.gh-axi}/lib/node_modules/gh-axi/skills/gh-axi";
  home.file.".prime/agent/skills/no-mistakes".source =
    "${agentPackages.no-mistakes-skill}/share/skills/no-mistakes";
  home.file.".prime/agent/skills/quota-axi".source =
    "${agentPackages.quota-axi}/lib/node_modules/quota-axi/skills/quota-axi";
  home.file.".prime/agent/skills/tasks-axi".source =
    "${agentPackages.tasks-axi}/lib/node_modules/tasks-axi/skills/tasks-axi";
  home.file.".prime/agent/skills/chrome-devtools-axi".source =
    "${agentPackages.chrome-devtools-axi}/lib/node_modules/chrome-devtools-axi/skills/chrome-devtools-axi";

  # Pi reads ~/.agents/skills directly. AGY and Prime use their client roots
  # above, while all three invoke the same user-owned binaries on PATH.

  # Pi extensions: authored extensions and Nix-packaged compaction extension.
  home.file.".pi/agent/extensions/calm".source =
    ../home/.pi/agent/extensions/calm;
  home.file.".pi/agent/extensions/terminal-status-title.js".source =
    ../home/.pi/agent/extensions/terminal-status-title.js;
  home.file.".pi/agent/extensions/pi-openai-server-compaction".source =
    "${agentPackages.pi-openai-server-compaction}";

  # Pi's adapter reads the shared user-global MCP file. AGY and Prime use their
  # own documented profile paths with the same server policy and binary.
  home.file.".config/mcp/mcp.json".source =
    ../home/.config/mcp/mcp.json;
  home.file.".gemini/config/mcp_config.json".source =
    ../home/.gemini/config/mcp_config.json;
  home.file.".gemini/antigravity-cli/mcp_config.json".source =
    ../home/.gemini/config/mcp_config.json;
}
