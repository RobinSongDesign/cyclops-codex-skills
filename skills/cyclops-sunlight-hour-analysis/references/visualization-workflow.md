# Visualization workflow

Read this file only after the export validator passes.

## Default delivery

Create the dashboard in English unless the user requests another language. A local working page is the default deliverable. Publish only when the user explicitly requests deployment; prefer private access.

Use the validated JSON/CSV as the only data source. Do not retype statistics from Grasshopper panels or screenshots.

## Required visual system

Match the established Cyclops sunlight dashboard:

- warm off-white paper background;
- white/off-white analysis panels with thin warm-grey rules;
- restrained dark ink typography;
- ordered sunlight palette from dark brown for low exposure through ochre to bright yellow for high exposure;
- compact editorial labels and generous whitespace;
- responsive desktop and mobile layouts;
- keyboard-focusable controls and accessible labels.

Copy or adapt [`assets/dashboard-theme.css`](../assets/dashboard-theme.css) for the shared design tokens and focus treatment.

Recommended palette:

```text
paper       #f3f2eb
surface     #fffefa
ink         #1d1d18
muted       #706e64
line        #dfdccf
low         #513b00
moderate    #a98500
high        #f1cf00
```

## Required dashboard sections

1. Header with `Cyclops · Sunlight Hours`, location, coordinates, and schedule.
2. Four KPIs: analysis-panel count, mean hours, median hours, and limited-exposure share.
3. Whole-building score distribution as a ten-band bar chart.
4. Donut composition using the same ordered colours.
5. Spatial floorplate map with a floor selector and hover/focus readout for panel index, period hours, and normalized hours per simulated day.
6. Floor profile showing limited, moderate, and high shares plus mean hours for every floor.
7. Method strip showing sun positions, one complete mesh, mesh faces, and obstruction-context counts.
8. Footer naming Cyclops and stating that direct-sun exposure does not replace illuminance, sDA, ASE, or compliance analysis.

## Score normalization

For a full-year result:

```text
daily score = annual sunlight hours / 365
```

Use the established bands:

```text
<1
1–<1.5
1.5–<2
2–<2.5
2.5–<3
3–<3.5
3.5–<4
4–<4.5
4.5–5
>5 h/day
```

Group the floor profile as:

```text
limited   <2 h/day
moderate  2–5 h/day
high      >5 h/day
```

For a partial schedule, normalize by the number of simulated calendar days and label the metric `mean direct sunlight per simulated day`. Do not call the raw value annual hours or reuse annual-hour threshold labels.

## Data and interaction rules

- Compute every KPI and chart from exported records at build or runtime.
- Preserve floor identity from `floor_index` and elevation; do not infer visual floor names beyond `L1`, `L2`, and so on without user confirmation.
- Use the point coordinates for the spatial map and keep one consistent colour domain across floors.
- Default the spatial map to the lowest floor, where obstruction effects are usually most informative.
- Hover and keyboard focus must reveal the same values.
- Ensure low exposure is dark and high exposure is bright consistently across the bar chart, donut, map, and floor profile.
- If more than one language is requested, use explicit routes such as `/` and `/en` plus a visible language switch.

## Validation before handoff

Check that the page builds and both desktop and mobile layouts remain usable. Verify visible totals against the validator output, especially panel count, mean, median, min/max, floor means, and score-band totals.

When the user asks to publish, use the available website-building and hosting workflow and return the final private URL. Otherwise return the local page location and instructions to open it.
