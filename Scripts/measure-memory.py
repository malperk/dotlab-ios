#!/usr/bin/env python3
"""Run each decoding fixture in a fresh macOS process to avoid shared high-water marks."""
import argparse
import datetime
import json
import platform
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("fixtures", type=Path)
parser.add_argument("--probe", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--repeats", type=int, default=5)
parser.add_argument("--include-simulation", action="store_true")
args = parser.parse_args()
if platform.system() != "Darwin":
    parser.error("This probe reports Darwin ru_maxrss in bytes; run it on macOS.")
if args.repeats < 1:
    parser.error("repeats must be positive")
manifest = json.loads((args.fixtures / "manifest.json").read_text())
rows = []
for fixture in manifest:
    for repeat_index in range(args.repeats):
        output = subprocess.check_output([str(args.probe.resolve()),
                    str((args.fixtures / fixture["file"]).resolve()), str(fixture["rawBytes"])], text=True)
        sample = json.loads(output)
        assert sample["decodedCount"] == fixture["count"]
        rows.append({**fixture, "repeatIndex": repeat_index, **sample})
simulation_rows = []
if args.include_simulation:
    for count in [10_000, 50_000, 100_000]:
        for mode in ["continuous", "sleep", "activeAoS", "activeSoA"]:
            for repeat_index in range(args.repeats):
                output = subprocess.check_output([str(args.probe.resolve()), "--simulate", mode, str(count)], text=True)
                sample = json.loads(output)
                assert sample["decodedCount"] == count
                simulation_rows.append({"count": count, "mode": mode, "repeatIndex": repeat_index, **sample})
report = {"platform": platform.platform(),
          "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "notes": "Release macOS decoding-only probe. Every sample is a fresh process. "
                   "ru_maxrss is the whole-process resident high-water mark in Darwin bytes, "
                   "including Swift/Foundation and file reading. Compressed input, uncompressed payload, "
                   "and decoded Float32 dots remain alive at the final sample. No generator, encoder, "
                   "renderer, or GPU buffers run in the child. Filesystem cache and allocator behavior affect results. "
                   "Baseline RSS is not subtracted from the peak; that difference would not isolate allocator peaks.",
          "simulationNotes": "Optional simulation samples each use a fresh process, the orbital generator, "
                             "and 240 identical scripted steps. Source, simulation storage, spatial grid, "
                             "and active membership are alive at sampling. No render buffers or GPU work. "
                             "SoA currently duplicates immutable home X/Y into planar arrays while keeping "
                             "the shared source dots for interaction/rendering. This is a measured implementation choice, "
                             "not a memory cost intrinsic to every SoA design.",
          "samples": rows, "simulationSamples": simulation_rows}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2) + "\n")
print(f"Wrote {len(rows)} decoding and {len(simulation_rows)} simulation memory samples to {args.output}")
