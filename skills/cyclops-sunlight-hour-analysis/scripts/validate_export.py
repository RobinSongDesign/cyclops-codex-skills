#!/usr/bin/env python3
"""Validate a Cyclops Sunlight Hour export and print a JSON summary."""

from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


REQUIRED_BASE_COLUMNS = {
    "floor_index",
    "floor_elevation_mm",
    "floor_panel_index",
    "global_panel_index",
    "x_mm",
    "y_mm",
    "z_mm",
}


def nested(data: dict[str, Any], *keys: str) -> Any:
    current: Any = data
    for key in keys:
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def close_enough(actual: float, expected: float, tolerance: float = 1e-6) -> bool:
    return math.isclose(actual, expected, rel_tol=tolerance, abs_tol=tolerance)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    output_dir = args.output_directory.expanduser().resolve()

    errors: list[str] = []
    warnings: list[str] = []
    paths = {
        "csv": output_dir / "sunlight_hours.csv",
        "json": output_dir / "sunlight_hours.json",
        "metadata": output_dir / "metadata.json",
    }
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing required {label} file: {path.name}")

    if errors:
        print(json.dumps({"valid": False, "errors": errors, "warnings": warnings}, indent=2))
        return 1

    try:
        metadata = json.loads(paths["metadata"].read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        print(json.dumps({"valid": False, "errors": [f"Cannot read metadata.json: {exc}"], "warnings": []}, indent=2))
        return 1

    rows: list[dict[str, str]] = []
    try:
        with paths["csv"].open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            columns = set(reader.fieldnames or [])
            missing = sorted(REQUIRED_BASE_COLUMNS - columns)
            if missing:
                errors.append(f"CSV is missing columns: {', '.join(missing)}")
            hour_column = "annual_sunlight_hours" if "annual_sunlight_hours" in columns else "sunlight_hours" if "sunlight_hours" in columns else None
            if hour_column is None:
                errors.append("CSV must contain annual_sunlight_hours or sunlight_hours")
            rows = list(reader)
    except OSError as exc:
        errors.append(f"Cannot read sunlight_hours.csv: {exc}")
        hour_column = None

    parsed: list[dict[str, Any]] = []
    global_indices: set[int] = set()
    if hour_column:
        for line_number, row in enumerate(rows, start=2):
            try:
                item = {
                    "floor_index": int(row["floor_index"]),
                    "floor_elevation_mm": float(row["floor_elevation_mm"]),
                    "floor_panel_index": int(row["floor_panel_index"]),
                    "global_panel_index": int(row["global_panel_index"]),
                    "x_mm": float(row["x_mm"]),
                    "y_mm": float(row["y_mm"]),
                    "z_mm": float(row["z_mm"]),
                    "hours": float(row[hour_column]),
                }
            except (KeyError, TypeError, ValueError) as exc:
                errors.append(f"Invalid numeric value on CSV line {line_number}: {exc}")
                continue
            if not all(math.isfinite(float(value)) for value in item.values()):
                errors.append(f"Non-finite numeric value on CSV line {line_number}")
                continue
            if item["hours"] < 0:
                errors.append(f"Negative sunlight hours on CSV line {line_number}")
            if item["global_panel_index"] in global_indices:
                errors.append(f"Duplicate global_panel_index {item['global_panel_index']}")
            global_indices.add(item["global_panel_index"])
            parsed.append(item)

    try:
        result_json = json.loads(paths["json"].read_text(encoding="utf-8-sig"))
        json_records = result_json.get("records", result_json) if isinstance(result_json, dict) else result_json
        if not isinstance(json_records, list):
            errors.append("sunlight_hours.json must contain a records array or be an array")
        elif len(json_records) != len(parsed):
            errors.append(f"JSON record count {len(json_records)} does not match CSV count {len(parsed)}")
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"Cannot read sunlight_hours.json: {exc}")

    complete_mesh_count = nested(metadata, "create_panels_input", "complete_mesh_count")
    if complete_mesh_count != 1:
        errors.append(f"Create Panels must receive one complete mesh item; metadata reports {complete_mesh_count!r}")

    expected_counts = {
        "analysis point count": nested(metadata, "analysis", "point_count"),
        "complete mesh face count": nested(metadata, "create_panels_input", "complete_mesh_faces"),
        "separate panel count": nested(metadata, "panelization", "separate_panel_meshes"),
        "display mesh face count": nested(metadata, "panelization", "display_coloured_mesh_faces"),
        "export row count": nested(metadata, "analysis", "export_row_count"),
    }
    for label, expected in expected_counts.items():
        if expected is not None and int(expected) != len(parsed):
            errors.append(f"{label} {expected} does not match CSV count {len(parsed)}")

    context = metadata.get("context", {}) if isinstance(metadata, dict) else {}
    excluded_layers = context.get("excluded_layers") if isinstance(context, dict) else None
    facade_layers = context.get("facade_layers_present") if isinstance(context, dict) else None
    if excluded_layers is None:
        warnings.append("Context exclusion metadata is absent; verify floorplates and facades were excluded manually")
    elif facade_layers:
        missing_facades = sorted(set(facade_layers) - set(excluded_layers))
        if missing_facades:
            errors.append(f"Facade layers are not explicitly excluded: {', '.join(missing_facades)}")

    floor_values: dict[int, list[float]] = defaultdict(list)
    floor_elevations: dict[int, list[float]] = defaultdict(list)
    for item in parsed:
        floor_values[item["floor_index"]].append(item["hours"])
        floor_elevations[item["floor_index"]].append(item["floor_elevation_mm"])

    values = [item["hours"] for item in parsed]
    summary: dict[str, Any] = {
        "valid": not errors,
        "output_directory": str(output_dir),
        "hour_column": hour_column,
        "panel_count": len(parsed),
        "errors": errors,
        "warnings": warnings,
        "floors": [],
    }

    if values:
        overall = {
            "minimum_hours": min(values),
            "maximum_hours": max(values),
            "mean_hours": statistics.fmean(values),
            "median_hours": statistics.median(values),
        }
        summary["overall"] = overall

        metadata_checks = {
            "minimum": nested(metadata, "analysis", "minimum_annual_hours"),
            "maximum": nested(metadata, "analysis", "maximum_annual_hours"),
            "mean": nested(metadata, "analysis", "mean_annual_hours"),
        }
        actuals = {"minimum": overall["minimum_hours"], "maximum": overall["maximum_hours"], "mean": overall["mean_hours"]}
        for label, expected in metadata_checks.items():
            if expected is not None and not close_enough(float(expected), actuals[label]):
                errors.append(f"Metadata {label} {expected} does not match computed value {actuals[label]}")

        for floor_index in sorted(floor_values):
            floor_hours = floor_values[floor_index]
            summary["floors"].append(
                {
                    "floor_index": floor_index,
                    "elevation_mm": statistics.median(floor_elevations[floor_index]),
                    "panel_count": len(floor_hours),
                    "minimum_hours": min(floor_hours),
                    "maximum_hours": max(floor_hours),
                    "mean_hours": statistics.fmean(floor_hours),
                    "median_hours": statistics.median(floor_hours),
                }
            )

        schedule_type = str(nested(metadata, "schedule", "type") or "").lower()
        timestamp_count = nested(metadata, "schedule", "timestamp_count")
        if "full_year" in schedule_type or timestamp_count in (8760, 8784):
            summary["full_year_daily_bands"] = {
                "limited_below_2h_per_day": sum(value < 730 for value in values),
                "moderate_2_to_5h_per_day": sum(730 <= value <= 1825 for value in values),
                "high_above_5h_per_day": sum(value > 1825 for value in values),
            }

    summary["valid"] = not errors
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
