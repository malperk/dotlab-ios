#!/usr/bin/env python3
"""Make static figures from recorded data. Requires matplotlib and numpy."""
import argparse
import collections
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

MODES = ["continuous", "sleep", "activeAoS", "activeSoA"]
LABELS = ["R0 Always on", "R1 Sleep", "R2 Active AoS", "R3 Active SoA"]
COLORS = ["#697789", "#af83ce", "#169d83", "#4e83c3"]


def grouped(ax, groups, value, ylabel, title):
    width = 0.19
    counts = [10_000, 50_000, 100_000]
    for i, mode in enumerate(MODES):
        medians, lower, upper = [], [], []
        for count in counts:
            values = [value(row) for row in groups[(count, mode)]]
            median = float(np.median(values))
            medians.append(median)
            lower.append(median - np.percentile(values, 25))
            upper.append(np.percentile(values, 75) - median)
        ax.bar(np.arange(3) + (i - 1.5) * width, medians, width,
               label=LABELS[i], color=COLORS[i], yerr=[lower, upper], capsize=2)
    ax.set_xticks(range(3), ["10K", "50K", "100K"])
    ax.set_xlabel("Particle count")
    ax.set_ylabel(ylabel)
    ax.set_title(title, loc="left", fontweight="bold")
    ax.grid(axis="y", alpha=0.18)
    ax.set_axisbelow(True)
    ax.legend(fontsize=8, frameon=False)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("input", type=Path)
parser.add_argument("--output", type=Path, required=True, help="Output path without suffix")
args = parser.parse_args()
report = json.loads(args.input.read_text())
if not report.get("simulation") and not report.get("trials"):
    parser.error("This overview requires CPU simulation or rendered-device trials.")
if "trials" in report and not report.get("completed"):
    parser.error("Refusing to plot an incomplete device comparison.")
plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False,
                     "svg.fonttype": "none"})
fig, axes = plt.subplots(1, 2, figsize=(12, 4.8))
if report.get("simulation"):
    rows = [r for r in report["codec"] if r["count"] == 100_000]
    for i, dataset in enumerate(["orbital", "uniform"]):
        subset = sorted([r for r in rows if r["dataset"] == dataset], key=lambda r: r["format"])
        axes[0].bar(np.arange(4) + (i - 0.5) * 0.36,
                    [r["compressedBytes"] / 1000 for r in subset], width=0.36,
                    color=["#169d83", "#4e83c3"][i], label=dataset)
    axes[0].set_xticks(range(4), ["Float32", "Quantized", "Planar", "Planar + delta"])
    axes[0].set_ylabel("LZFSE-compressed size (decimal kB)")
    axes[0].set_title("Encoding · 100K dots", loc="left", fontweight="bold")
    axes[0].legend(frameon=False)
    axes[0].grid(axis="y", alpha=0.18); axes[0].set_axisbelow(True)
    groups = collections.defaultdict(list)
    for row in report["simulation"]:
        groups[(row["count"], row["mode"])].append(row)
    grouped(axes[1], groups, lambda r: r["updateP95MS"], "Physics step p95 (ms)",
            "CPU simulation · macOS")
    title = "DotLab · host measurements (not iPhone frame rates)"
else:
    groups = collections.defaultdict(list)
    for row in report["trials"]:
        groups[(row["count"], row["mode"])].append(row)
    grouped(axes[0], groups, lambda r: r["phases"]["interaction"]["simulationP95MS"],
            "Physics work per rendered callback, p95 (ms)", "Interaction · CPU physics")
    grouped(axes[1], groups, lambda r: r["phases"].get("idle", {}).get("frames", 0),
            "Frames submitted during final idle", f"Idle · target {report['idleSeconds']:g} seconds")
    prefix = "SIMULATOR VALIDATION ONLY" if report["simulator"] else report["deviceModel"]
    title = f"DotLab · {prefix} · {report['protocolName']}"
fig.suptitle(title, fontsize=13, fontweight="bold")
fig.text(0.02, 0.015, f"Source: {args.input.name} · Timing/work bars: trial medians; error bars: interquartile range.",
         fontsize=8, color="#555555")
fig.tight_layout(rect=(0, 0.05, 1, 0.92))
args.output.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(args.output.with_suffix(".png"), dpi=180,
            metadata={"Author": "Alper Karatas", "Description": title})
fig.savefig(args.output.with_suffix(".svg"),
            metadata={"Creator": "Alper Karatas / DotLab", "Date": report["environment"]["timestamp"]})
print(f"Wrote {args.output}.png and .svg")
