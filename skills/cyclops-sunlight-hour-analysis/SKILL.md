---
name: cyclops-sunlight-hour-analysis
description: Bootstrap RhinoMCP when needed, then run a confirmation-gated Cyclops Sunlight Hour workflow for Rhino/Grasshopper floorplates, export validated panel results, and create the standard interactive sunlight dashboard. Use for Cyclops floorplate sunlight-hour setup, analysis, troubleshooting, data export, or visualization; facade analysis is outside the current version.
---

# Cyclops Sunlight Hour Analysis

Deliver the workflow in two phases: **Analysis** and **Visualization**. The current version supports horizontal floorplates only.

## RhinoMCP dependency bootstrap

Before the confirmation gate, check whether Rhino MCP tools such as `mcp__rhino__list_slots` are available in the current session.

- If Rhino MCP tools are available, continue to the confirmation gate.
- If they are unavailable on Windows, tell the user that the official McNeel `Rhino-MCP-Platform` package and the Codex MCP configuration will be installed or repaired. Then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ensure_rhinomcp.ps1 -InstallIfMissing
```

- Parse the script's JSON result. If `restartRequired` is `true`, stop the workflow and ask the user to restart Rhino and Codex. After Rhino restarts, have them run `MCPConnect` in Rhino if the MCP server is not already listening, then invoke this skill again.
- If the script reports `missing_rhino`, explain that Rhino must be installed first. Do not install Rhino itself.
- If the script reports `missing_dependency` or `install_failed`, show its message and use [references/rhinomcp-bootstrap.md](references/rhinomcp-bootstrap.md) for recovery.
- Never claim RhinoMCP is connected merely because the package or config exists. Verify that a Rhino MCP tool succeeds after restart.

The bootstrap currently supports Rhino 8 on Windows. Do not attempt package installation on another operating system; provide the manual McNeel setup link from the reference instead.

## Mandatory confirmation gate

Do not open Grasshopper, open or modify a definition, panelize geometry, change Rhino data, or start an analysis until every item below is explicitly confirmed. Ask for the missing items in one concise grouped message.

1. Exact Rhino layer name(s) containing the analysis geometry.
2. Exact Rhino layer name(s) containing real obstruction context.
3. Whether the target is `floorplate` or `facade`.
4. Whether facade geometry exists, and its exact layer name(s).
5. Location name, latitude, and longitude.
6. Analysis time range, including start, end, and timestep. Offer hourly steps and a 0° solar-elevation cutoff as defaults, but require confirmation.

Ask the user to supply exact existing layer names. If they need help mapping an existing model, ask permission for a read-only Rhino layer inventory, propose candidates, then return to this gate. Read-only inventory is the only action allowed before confirmation.

Offer this model organization when layers are not yet clean:

```text
SUNLIGHT_ANALYSIS::FLOORPLATES
SUNLIGHT_CONTEXT::TERRAIN
SUNLIGHT_CONTEXT::NEIGHBORING_BUILDINGS
SUNLIGHT_EXCLUDE::FACADES
```

Before proceeding, repeat a compact confirmation record:

```text
Analysis type:
Analysis layer(s):
Context layer(s):
Facade layer(s), explicitly excluded:
Location and coordinates:
Time range / timestep / cutoff:
```

Proceed only after the user confirms this record. Do not treat an earlier file-opening request or a generic “go ahead” as confirmation of missing fields.

## Scope decision

- For `floorplate`, continue with the Analysis phase.
- For `facade`, stop before Grasshopper work. Explain that facade analysis needs vertical zoning followed by panelization and is intentionally deferred in this version. Ask the user to switch to floorplates or request a future facade extension.
- For floorplate analysis, never add facade geometry to the analysis set or the Cyclops context. It would create artificial self-obstruction. Also exclude the active floorplates themselves from context.

## Phase 1 — Analysis

After the gate is complete, read [references/analysis-workflow.md](references/analysis-workflow.md) and execute it against the confirmed Rhino instance and model.

Non-negotiable invariants:

- Feed `Create Panels` exactly one complete Mesh item. Join disjoint floor meshes into one Mesh object and flatten the input; do not send a list of separate meshes.
- Connect the same analysis panel mesh to the mesh-colouring/display path.
- Connect panel analysis points to the Cyclops Sunlight Hour analysis component.
- Add only confirmed, real obstruction geometry to a Cyclops `Obstruction` context group.
- Exclude all facade layers during floorplate analysis, even when facade geometry is present in the Rhino model.
- Verify point count, result count, coloured mesh face count, and exported row count agree before declaring success.

After solving, export CSV, JSON, and metadata as specified in [references/export-and-validation.md](references/export-and-validation.md). Run the included validator before visualization.

## Phase 2 — Visualization

After validated data exists, read [references/visualization-workflow.md](references/visualization-workflow.md) and build the standard dashboard.

- Default to English. Add or switch to another language only when the user asks.
- Preserve the established off-white, ochre, yellow, and dark-brown visual system.
- Include whole-building distribution, donut composition, floor selector, spatial panel map with hover values, floor profiles, method settings, and the direct-sunlight limitation note.
- Label a result “annual” only when the confirmed schedule covers a full year.
- Create a local working dashboard by default. Publish or share it externally only when the user explicitly requests deployment; prefer private access.

## Completion report

Report:

- confirmed layers, exclusions, location, and schedule;
- complete-mesh, panel, point, result, display-face, and export-row counts;
- context object counts and types;
- min, max, mean, and median sunlight hours overall and by floor;
- export directory and dashboard location;
- any warnings, especially missing facade exclusions or a partial-year schedule.

Never present Sunlight Hours as proof of indoor daylight or regulatory compliance.
