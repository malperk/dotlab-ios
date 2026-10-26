import DotLabCore
import Foundation

struct Report: Codable {
    var environment: EnvironmentInfo
    var codec: [CodecMeasurement]
    var simulation: [SimulationMeasurement]
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let quick = arguments.contains("--quick")
    let codecOnly = arguments.contains("--codec-only")
    let output: String
    if let index = arguments.firstIndex(of: "--output"), arguments.indices.contains(index + 1) {
        output = arguments[index + 1]
    } else { output = "Results/local/macos.json" }
    if arguments.contains("--help") {
        print("Usage: swift run -c release dotbench [--quick] [--codec-only] [--output path.json]")
        exit(0)
    }
    var report = Report(environment: EnvironmentInfo(platform: "macOS / CPU only",
        notes: "Release recommended. No GPU, display, iPhone energy, or app-startup measurements. Decode samples exclude disk I/O and include format validation. Host may be shared with other processes."),
        codec: [], simulation: [])
    for count in [10_000, 50_000, 100_000] {
        for kind in DatasetKind.allCases {
            print("Encoding \(kind.rawValue), \(count) dots…")
            report.codec += try CodecBenchmark.run(dots: Dataset.make(count: count, kind: kind),
                                                   dataset: kind, repeats: quick ? 3 : 20)
        }
    }
    if !codecOnly {
        let repeats = quick ? 1 : 5
        // Seeded shuffle reduces systematic order bias. No concurrency in timed work.
        var trials = (0..<repeats).flatMap { repeatIndex in
            [10_000, 50_000, 100_000].flatMap { count in
                SimulationMode.allCases.map { (count, $0, repeatIndex) }
            }
        }
        var random = SplitMix64(state: 82)
        for i in stride(from: trials.count - 1, through: 1, by: -1) {
            trials.swapAt(i, Int(random.next() % UInt64(i + 1)))
        }
        for (count, mode, repeatIndex) in trials {
            print("Simulating \(count), \(mode.rawValue), repeat \(repeatIndex + 1)…")
            report.simulation.append(SimulationBenchmark.run(count: count, mode: mode,
                repeatIndex: repeatIndex, interactionSteps: quick ? 240 : 1200))
        }
    }
    let url = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(report).write(to: url, options: .atomic)
    print("Wrote \(report.codec.count) codec rows and \(report.simulation.count) CPU trials to \(output)")
} catch {
    fputs("dotbench: \(error)\n", stderr)
    exit(1)
}
