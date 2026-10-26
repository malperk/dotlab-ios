#!/usr/bin/env python3
"""Check recorded invariants; never substitute simulator timing for device evidence."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("input", type=Path)
parser.add_argument("--require-physical", action="store_true")
parser.add_argument("--standard", action="store_true")
args = parser.parse_args()
report = json.loads(args.input.read_text())
assert report["codec"], "No encoding measurements"
for row in report["codec"]:
    assert row["maxPositionErrorPixels"] <= 0.25, "Position error exceeded tolerance"
    assert row["maxRadiusErrorPixels"] <= 0.25, "Radius error exceeded tolerance"
    assert row["compressedBytes"] > 0
    assert row["rawBytes"] == 16 + row["count"] * (12 if row["format"] == 0 else 5)
for row in report.get("simulation", []):
    assert row["settled"], "A CPU simulation did not settle"
if "trials" in report:
    assert report["completed"], "Only a partial run was recorded"
    assert report["buildConfiguration"] == "Release", "Debug timings are not comparable"
    repeats = 5 if report["protocolName"].startswith("standard") else 1
    if args.standard:
        assert repeats == 5, "Standard protocol required"
    if args.require_physical:
        assert not report["simulator"], "Physical device required"
    assert len(report["trials"]) == 12 * repeats, "Missing trials"
    keys = {(r["count"], r["mode"], r["repeatIndex"]) for r in report["trials"]}
    assert len(keys) == 12 * repeats, "Duplicate trials"
    for row in report["trials"]:
        assert row["settled"], "A rendered simulation did not settle"
        assert row.get("metalError") is None, "A Metal command failed"
        assert row["phases"]["interaction"]["frames"] > 0, "No interaction rendered"
        idle = row["phases"].get("idle", {})
        if row["mode"] == "continuous":
            assert idle.get("frames", 0) > 0, "Baseline unexpectedly stopped"
        else:
            assert idle.get("frames", 0) == 0, "Optimized renderer drew while idle"
            assert idle.get("simulationSteps", 0) == 0, "Optimized simulation ran while idle"
print("PASS: encoding error bounds, schema, settlement, and available rendering invariants.")
