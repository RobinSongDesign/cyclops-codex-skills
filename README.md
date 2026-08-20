# Cyclops Codex Skills

Reusable Codex skills for Cyclops workflows in Rhino and Grasshopper.

## Available skills

### `cyclops-sunlight-hour-analysis`

Runs a confirmation-gated sunlight-hour workflow for horizontal floorplates, validates exported panel results, and creates the standard interactive dashboard.

The skill checks for RhinoMCP before analysis. On Windows with Rhino 8, it can install McNeel's official `Rhino-MCP-Platform` package through Rhino's Yak package manager and repair the Codex MCP configuration. A first-time installation still requires restarting Rhino and Codex.

## Install

Download this repository as a ZIP or clone it, then copy the skill folder into your personal Codex skills directory:

```powershell
Copy-Item -Recurse -Force `
  ".\skills\cyclops-sunlight-hour-analysis" `
  "$env:USERPROFILE\.codex\skills\cyclops-sunlight-hour-analysis"
```

Restart Codex, then invoke:

```text
$cyclops-sunlight-hour-analysis
```

## Requirements and scope

- Codex with personal skills support
- Rhino 8 for Windows
- Grasshopper with the Cyclops components needed by the analysis definition
- Horizontal floorplate analysis only in the current version; facade analysis is intentionally deferred

RhinoMCP automatic setup uses only McNeel's official Yak package and official package source. It does not install Rhino itself.

## Repository structure

```text
skills/
  cyclops-sunlight-hour-analysis/
    SKILL.md
    agents/
    assets/
    references/
    scripts/
```

More Cyclops skills can be added as sibling folders under `skills/`.

## 中文说明

下载或克隆本仓库后，将 `skills/cyclops-sunlight-hour-analysis` 复制到 `%USERPROFILE%\.codex\skills\`，重启 Codex，再调用 `$cyclops-sunlight-hour-analysis`。

首次运行时，如果没有 RhinoMCP，Skill 会在 Windows + Rhino 8 环境下通过 Rhino 自带的 Yak 安装 McNeel 官方包并修复 Codex 配置。安装后需要重启 Rhino 和 Codex。
