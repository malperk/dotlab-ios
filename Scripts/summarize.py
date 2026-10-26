#!/usr/bin/env python3
"""Convert a raw benchmark JSON export to an auditable Markdown summary."""
import argparse
import collections
import json
import statistics
from pathlib import Path

FORMATS = {
    0: "Float32 interleaved",
    1: "Quantized interleaved",
    2: "Quantized planar",
    3: "Quantized planar + delta",
}


def summarize(report):
    if "samples" in report and "environment" not in report:
        groups = collections.defaultdict(list)
        for row in report["samples"]:
            groups[(row["dataset"], row["count"], row["format"])].append(row)
        lines = ["# DotLab decoding memory", "", f"Recorded: {report['timestamp']}", "",
                 report["platform"], "", report["notes"], "",
                 "Medians across independent processes. MiB = 1,048,576 bytes. Peaks include process startup.", "",
                 "| Dataset | Dots | Format | Repeats | Baseline RSS (MiB) | Peak process RSS (MiB) | Final RSS (MiB) |",
                 "|---|---:|---|---:|---:|---:|---:|"]
        for (dataset, count, format_id), rows in sorted(groups.items()):
            med = lambda key: statistics.median(row[key] for row in rows) / 1_048_576
            lines.append(f"| {dataset} | {count:,} | {FORMATS[format_id]} | {len(rows)} | "
                         f"{med('baselineResidentBytes'):.2f} | {med('peakProcessResidentBytes'):.2f} | "
                         f"{med('finalResidentBytes'):.2f} |")
        if report.get("simulationSamples"):
            groups = collections.defaultdict(list)
            for row in report["simulationSamples"]:
                groups[(row["count"], row["mode"])].append(row)
            lines += ["", "## Simulation process memory", "", report["simulationNotes"], "",
                      "| Dots | Mode | Repeats | Peak process RSS (MiB) | Final RSS (MiB) |",
                      "|---:|---|---:|---:|---:|"]
            for (count, mode), rows in sorted(groups.items()):
                peak = statistics.median(row["peakProcessResidentBytes"] for row in rows) / 1_048_576
                final = statistics.median(row["finalResidentBytes"] for row in rows) / 1_048_576
                lines.append(f"| {count:,} | {mode} | {len(rows)} | {peak:.2f} | {final:.2f} |")
        return "\n".join(lines) + "\n"
    env = report["environment"]
    lines = ["# DotLab benchmark results", "", f"Recorded: {env['timestamp']}", "",
             f"Platform: {env['platform']} · {env['os']}", "", env["notes"], ""]
    if "simulator" in report:
        lines += [f"Device: {report['deviceModel']} · {report['gpu']}", "",
                  f"Simulator: **{report['simulator']}** · Build: {report['buildConfiguration']} · "
                  f"Protocol: {report['protocolName']} · Complete: {report['completed']}", ""]
        if report["simulator"]:
            lines += ["> Simulator data verifies behavior only. It does not establish iPhone GPU, CPU, or energy performance.", ""]
    lines += ["## Encoding", "", "All sizes include the 16-byte file header. Timing excludes disk and network I/O.", "",
              "| Dataset | Dots | Format | Raw bytes | LZFSE bytes | Open p50 (ms) | Open p95 (ms) | Max position error (px) | Max radius error (px) |",
              "|---|---:|---|---:|---:|---:|---:|---:|---:|"]
    for row in report["codec"]:
        lines.append(f"| {row['dataset']} | {row['count']:,} | {FORMATS[row['format']]} | "
                     f"{row['rawBytes']:,} | {row['compressedBytes']:,} | "
                     f"{row['totalP50MS']:.3f} | {row['totalP95MS']:.3f} | "
                     f"{row['maxPositionErrorPixels']:.5f} | {row['maxRadiusErrorPixels']:.5f} |")
    if report.get("simulation"):
        groups = collections.defaultdict(list)
        for row in report["simulation"]:
            groups[(row["count"], row["mode"])].append(row)
        lines += ["", "## CPU simulation microbenchmark", "",
                  "Median of trial percentiles. Each timed sample is one 1/120 s physics step during interaction. "
                  "These are not rendered frame times. Total work includes settling; hit tests cover interaction.", "",
                  "| Dots | Mode | Repeats | Update p50 (ms) | Update p95 (ms) | Updated / trial | Hit tests / trial | All settled |",
                  "|---:|---|---:|---:|---:|---:|---:|---|"]
        for (count, mode), rows in sorted(groups.items()):
            median = lambda key: statistics.median(row[key] for row in rows)
            lines.append(f"| {count:,} | {mode} | {len(rows)} | {median('updateP50MS'):.4f} | "
                         f"{median('updateP95MS'):.4f} | {median('totalUpdated'):,.0f} | "
                         f"{median('totalHitTests'):,.0f} | {all(row['settled'] for row in rows)} |")
    if report.get("trials"):
        lines += ["", "## Rendered trials", "",
                  "Submission is elapsed wall time, including waits. Missed refreshes are callback-spacing estimates. "
                  "A zero idle-frame count means the renderer submitted no new frames during that phase.", "",
                  "| Dots | Mode | Repeat | Submit p95 (ms) | GPU p95 (ms) | Interval p95 (ms) | Est. missed | Idle frames | Idle steps | Settled | Thermal start/end |",
                  "|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---|"]
        for row in report["trials"]:
            active = row["phases"].get("interaction", {})
            idle = row["phases"].get("idle", {})
            lines.append(f"| {row['count']:,} | {row['mode']} | {row['repeatIndex'] + 1} | "
                         f"{active.get('submissionP95MS', 0):.3f} | {active.get('gpuP95MS', 0):.3f} | "
                         f"{active.get('intervalP95MS', 0):.3f} | {active.get('estimatedMissedRefreshes', 0)} | "
                         f"{idle.get('frames', 0)} | {idle.get('simulationSteps', 0)} | {row['settled']} | "
                         f"{row['thermalStart']}/{row['thermalEnd']} |")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = summarize(json.loads(args.input.read_text()))
    if args.output:
        args.output.write_text(result)
    else:
        print(result, end="")
