{ ... }:
{
  # One tracked AGENTS.md is shared by AGY and Pi. Prime keeps its own policy.
  home.file.".pi/agent/AGENTS.md".source = ../AGENTS.md;
  home.file.".gemini/GEMINI.md".source = ../AGENTS.md;

  # The same reviewed Caveman skill is visible in both agents' global skill roots.
  home.file.".agents/skills/caveman".source =
    ../home/.agents/skills/caveman;
  home.file.".gemini/antigravity-cli/skills/caveman".source =
    ../home/.agents/skills/caveman;

  # Pi's adapter reads the shared user-global MCP file. AGY uses its own
  # documented profile path, with the same server policy expressed in its schema.
  home.file.".config/mcp/mcp.json".source =
    ../home/.config/mcp/mcp.json;
  home.file.".gemini/config/mcp_config.json".source =
    ../home/.gemini/config/mcp_config.json;
  home.file.".gemini/antigravity-cli/mcp_config.json".source =
    ../home/.gemini/config/mcp_config.json;
}
