# RhinoMCP bootstrap and recovery

Use this reference only when Rhino MCP tools are unavailable or the bootstrap script reports an error.

## What the helper changes

On Windows with Rhino 8, `scripts/ensure_rhinomcp.ps1`:

1. Locates Rhino's official `Yak.exe` package manager.
2. Looks for an installed `Rhino-MCP-Platform` router.
3. When `-InstallIfMissing` is supplied, installs the official McNeel package with `yak install Rhino-MCP-Platform` if no router exists.
4. Adds or repairs only the `[mcp_servers.rhino]` section of the user's Codex `config.toml`.
5. Creates a timestamped backup before changing an existing Codex config.
6. Returns a single JSON object describing the result and whether Rhino/Codex must be restarted.

The helper does not install Rhino, start an analysis, or edit Rhino model data.

## Expected recovery sequence

1. Close and reopen Rhino after a first package installation.
2. Run `MCPConnect` in Rhino if RhinoMCP is not already listening.
3. Restart Codex after its MCP configuration is added or repaired.
4. Invoke this skill again and verify a Rhino MCP tool succeeds.

## Manual fallback

Follow McNeel's official setup instructions when automatic installation is unsupported or fails:

- Codex setup: <https://mcneel.github.io/RhinoMCP/docs/getting-started/codex/>
- RhinoMCP repository: <https://github.com/mcneel/RhinoMCP>

Do not download RhinoMCP binaries from an unofficial mirror.
