# Analysis workflow

Read this file only after the mandatory confirmation gate in `SKILL.md` is complete.

## 1. Start the Rhino and Grasshopper session

1. List available Rhino instances and identify the instance containing the confirmed model.
2. Verify the active Rhino document and units. Record the document path.
3. Open Grasshopper in that instance.
4. Locate the installed Cyclops tutorial or example whose name contains `SunlightHour` or `Sunlight Hour`. Prefer the installed example; otherwise ask the user for its path.
5. Open the example and immediately save a working copy beside the Rhino model or in a user-approved project directory. Never overwrite the installed tutorial.
6. Identify the tutorial groups for geometry processing, panel creation, sun rig, Sunlight Hour analysis, gradient, coloured mesh, and result export. Preserve the reference file layout when practical.

Use direct Rhino/Grasshopper document tools when available. UI automation is a fallback, not a requirement.

## 2. Collect the confirmed geometry

Read objects only from the confirmed layers.

### Floorplate analysis geometry

- Accept horizontal Breps or meshes representing the floorplates.
- For slab Breps, extract the upward-facing top surface. Do not panelize bottom or vertical edge faces.
- Reject or flag duplicate, hidden, invalid, or zero-area geometry.
- Group floors by confirmed source identity when available and by elevation as a fallback. Record the unique elevations.
- Keep the active floorplates out of the context set.

### Context geometry

Include only confirmed real obstructions, such as terrain, topography, adjacent buildings, permanent canopies, or other external shading objects.

Never include:

- the active floorplates;
- any facade layer during floorplate analysis;
- analysis points or display meshes;
- duplicated copies of the same obstruction.

Create one clearly named Cyclops geometry group, for example `Project context | Terrain + Neighbours`, and set its intersection type to `Obstruction`.

## 3. Geometry Process and panelization

Adapt the tutorial's `Geometry Process` and `Create Panels` pattern.

1. Reparameterize or otherwise normalize each selected top surface when required by the tutorial definition.
2. Use the tutorial's panelization logic as the starting point. If the user did not specify a target panel size or U/V count, keep the example's resolution and report it rather than inventing a different accuracy target.
3. Mesh all generated floor panels.
4. Join all floor panel meshes into exactly one Grasshopper Mesh item. Disjoint floor components are acceptable inside that one Mesh object.
5. Flatten the `Create Panels` mesh input so the component receives one complete mesh, not a data tree or a list of separate panel meshes.
6. Preserve floor membership in exported attributes by source mapping or panel-centroid elevation.

Record:

- U/V count or target panel size;
- complete mesh item count;
- complete mesh vertex and face counts;
- separate panel count;
- analysis-point count by floor.

The required pre-analysis check is:

```text
complete mesh items = 1
complete mesh faces = separate panels = analysis points
```

Stop and fix the geometry path if this check fails.

## 4. Sun rig and schedule

Set the confirmed latitude and longitude explicitly. Do not infer coordinates from the Rhino document.

Build timestamps from the confirmed range and timestep. For full-year hourly analysis, verify 8,760 timestamps in a non-leap reference year. Filter or generate solar positions according to the confirmed elevation cutoff, normally 0°.

Record:

- location name, latitude, and longitude;
- first and last timestamp;
- timestep;
- timestamp count;
- cutoff elevation;
- sun positions retained above the cutoff.

Do not call a partial-year run “annual.”

## 5. Required Grasshopper wiring

Match the tutorial component versions available in the installed Cyclops package, while preserving these logical connections:

1. The one complete panel mesh enters the `Create Panels`/analysis geometry path as one flattened item.
2. Panel analysis points enter the Cyclops `Sunlight Hour Analysis` analysis-point input.
3. The configured Sun Rig enters the sunlight component.
4. The confirmed Cyclops `Obstruction` group enters the context/intersection input.
5. The sunlight-hour values enter the gradient or colour-mapping component.
6. The same panel mesh used for analysis enters the mesh-colouring/display mesh input.
7. The gradient colours enter the coloured-mesh colour input.

The display mesh connection is mandatory. A successful numeric result with no mesh connected for colouring is incomplete.

## 6. Solve and verify

Recompute after all inputs are connected. Wait for the Cyclops component to finish and inspect component messages.

Verify:

- no null analysis points;
- no component errors or expired results;
- result count equals analysis-point count;
- coloured display mesh face count equals result count;
- gradient domain covers the actual result minimum and maximum;
- every confirmed context layer is present once;
- facade layers and active floorplates are absent from context;
- floor elevations and per-floor point counts are plausible.

If results are all zero or implausibly uniform, recheck location, schedule, normals, unit scale, context classification, facade exclusion, and whether the complete mesh input is truly one item.

Only after these checks pass should the definition be saved and data exported.
