# Export and validation

Use this schema after a successful Cyclops solve. Keep the raw result available for later re-visualization without reopening Grasshopper.

## Output directory

Use a project-local folder such as:

```text
Cyclops_Output/<model-name>_SunlightHour/
```

Write:

```text
sunlight_hours.csv
sunlight_hours.json
metadata.json
```

## CSV columns

Use one row per analysis panel:

```text
floor_index
floor_elevation_mm
floor_panel_index
global_panel_index
x_mm
y_mm
z_mm
normal_x
normal_y
normal_z
sunlight_hours
```

For a full-year schedule, `annual_sunlight_hours` may be used instead of `sunlight_hours`. Do not use the annual name for partial schedules.

## Required metadata

Include these sections:

- `rhino_document`, `grasshopper_document`, source layers, and coordinate units;
- location name, latitude, and longitude;
- schedule type, start/end timestamps, timestep, timestamp count, cutoff, and retained sun-position count;
- complete mesh item, vertex, and face counts;
- panelization settings and panel/display counts;
- floor elevations, counts, and min/max/mean values;
- context layers, geometry counts, Cyclops intersection type, and group name;
- explicitly excluded layers, including all facade layers for floorplate analysis;
- component names, result branch count, point count, min/max/mean, and export row count.

Recommended context fields:

```json
{
  "context": {
    "included_layers": [],
    "excluded_layers": [],
    "facade_layers_present": [],
    "intersection_type": "Obstruction",
    "brep_count": 0,
    "mesh_count": 0
  }
}
```

## Integrity checks

Run:

```powershell
python scripts/validate_export.py <output-directory>
```

The validator checks files, columns, numeric values, counts, floor summaries, and the single-complete-mesh invariant. It warns when facade-exclusion metadata is absent because legacy exports may not contain that field.

Do not continue to visualization when validation reports an error. Fix the Grasshopper or export path and re-export.
