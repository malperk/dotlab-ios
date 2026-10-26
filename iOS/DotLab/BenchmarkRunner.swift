import DotLabCore
import Foundation
import MetalKit
import Darwin
import os

struct PhaseSummary: Codable {
    var frames: Int
    var simulationSteps: Int
    var updated: Int
    var hitTests: Int
    var submissionP50MS: Double
    var submissionP95MS: Double
    var simulationP95MS: Double
    var gpuP95MS: Double
    var intervalP95MS: Double
    var estimatedMissedRefreshes: Int
    var droppedSimulationSeconds: Double

    init(_ samples: PhaseSamples) {
        frames = samples.frames; simulationSteps = samples.simulationSteps
        updated = samples.updated; hitTests = samples.hitTests
        submissionP50MS = Statistics.percentile(samples.cpuMS, 0.5)
        submissionP95MS = Statistics.percentile(samples.cpuMS, 0.95)
        simulationP95MS = Statistics.percentile(samples.simulationMS, 0.95)
        gpuP95MS = Statistics.percentile(samples.gpuMS, 0.95)
        intervalP95MS = Statistics.percentile(samples.intervalsMS, 0.95)
        estimatedMissedRefreshes = samples.estimatedMissedRefreshes
        droppedSimulationSeconds = samples.droppedSimulationSeconds
    }
}

struct DeviceTrial: Codable {
    var count: Int
    var mode: SimulationMode
    var repeatIndex: Int
    var phases: [String: PhaseSummary]
    var rawSamples: [String: PhaseSamples]
    var settled: Bool
    var settleSeconds: Double
    var readyToSubmitFirstFrameMS: Double
    var residentBytes: UInt64
    var thermalStart: Int
    var thermalEnd: Int
    var metalError: String?
}

struct DeviceReport: Codable {
    var environment: EnvironmentInfo
    var deviceModel: String
    var gpu: String
    var simulator: Bool
    var protocolName: String
    var buildConfiguration: String
    var targetFPS = 60
    var preIdleSeconds: Double
    var interactionSeconds: Double
    var idleSeconds: Double
    var maxSettleSeconds = 10.0
    var codec: [CodecMeasurement] = []
    var trials: [DeviceTrial] = []
    var completed = false
    var interruption: String?
}

@MainActor
final class LabModel: ObservableObject {
    @Published var renderer: ParticleRenderer?
    @Published var count = 50_000
    @Published var mode: SimulationMode = .activeAoS
    @Published var isRunning = false
    @Published var status = "Touch the field to disturb the orbit."
    @Published var activeCount = 0
    @Published var frameCount = 0
    @Published var submissionMS = 0.0
    @Published var gpuMS = 0.0
    @Published var sleeping = true
    @Published var codecRows: [CodecMeasurement] = []
    @Published var exportURL: URL?
    @Published var progress = 0.0
    @Published var completedTrials = 0
    @Published var errorMessage: String?
    private var suiteTask: Task<Void, Never>?
    private var statsTask: Task<Void, Never>?
    private let logger = OSLog(subsystem: "com.alperkaratas.dotlab", category: .pointsOfInterest)

    init() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--count"), args.indices.contains(index + 1),
           let value = Int(args[index + 1]), [10_000, 50_000, 100_000].contains(value) { count = value }
        if let index = args.firstIndex(of: "--mode"), args.indices.contains(index + 1),
           let value = SimulationMode(rawValue: args[index + 1]) { mode = value }
        do {
            var dots = Dataset.make(count: count)
            if let index = args.firstIndex(of: "--format"), args.indices.contains(index + 1),
               let value = UInt8(args[index + 1]), let format = DotFormat(rawValue: value) {
                dots = try DotCodec.decode(DotCodec.encode(dots, format: format))
            }
            renderer = try ParticleRenderer(dots: dots, mode: mode)
        }
        catch { errorMessage = "Metal initialization failed: \(error)" }
        statsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                guard let self else { return }
                self.refreshStats()
            }
        }
    }

    func refreshStats() {
        guard let renderer else { return }
        activeCount = renderer.simulation.activeCount
        frameCount = renderer.totalFrames
        submissionMS = renderer.lastCPU; gpuMS = renderer.lastGPU
        sleeping = renderer.view?.isPaused ?? true
    }

    func reset() {
        guard !isRunning else { return }
        do {
            try renderer?.reset(dots: Dataset.make(count: count), mode: mode)
            status = "Touch the field to disturb the orbit."
        } catch { errorMessage = "Could not reset: \(error)" }
    }

    func replay() {
        guard !isRunning, let renderer else { return }
        reset()
        renderer.scriptStart = CACurrentMediaTime()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard let self, !self.isRunning else { return }
            self.renderer?.scriptStart = nil
        }
    }

    func analyzeCodec() {
        guard !isRunning else { return }
        isRunning = true
        renderer?.view?.isPaused = true
        status = "Measuring all four encodings…"
        let count = count
        Task {
            do {
                let rows = try await Task.detached(priority: .userInitiated) {
                    try CodecBenchmark.run(dots: Dataset.make(count: count), dataset: .orbital)
                }.value
                codecRows = rows
                status = "Same points. Same LZFSE compressor. Same runtime layout."
            } catch { errorMessage = "Encoding benchmark failed: \(error)" }
            isRunning = false
            if mode == .continuous { renderer?.wake() }
        }
    }

    func cancel(reason: String = "Cancelled by user") {
        status = reason
        suiteTask?.cancel()
    }

    func startSuite(quick: Bool) {
        guard !isRunning, let renderer else { return }
        suiteTask = Task {
            isRunning = true; exportURL = nil; completedTrials = 0
            renderer.scriptStart = nil; renderer.touch = nil; renderer.view?.isPaused = true
            UIApplication.shared.isIdleTimerDisabled = true
            defer {
                isRunning = false; renderer.scriptStart = nil; renderer.touch = nil
                UIApplication.shared.isIdleTimerDisabled = false
                suiteTask = nil
            }
            #if targetEnvironment(simulator)
            let simulator = true
            #else
            let simulator = false
            #endif
            #if DEBUG
            let buildConfiguration = "Debug"
            #else
            let buildConfiguration = "Release"
            #endif
            let duration = quick ? (pre: 1.0, interaction: 2.0, idle: 3.0) : (pre: 10.0, interaction: 10.0, idle: 30.0)
            var report = DeviceReport(environment: EnvironmentInfo(platform: "iOS",
                notes: "Release build required for interpretation. Metal instanced quads; CPU fixed-step physics. Submission times are elapsed wall time including drawable/semaphore waits, not process CPU utilization. GPU execution is command-buffer time, not display latency. Missed refreshes are estimates from callback spacing. RSS is a post-trial snapshot, not peak memory. No automatic energy measurements. Trials stop on backgrounding; thermal state is recorded. Codec viewport is 1179×1179 physical pixels."),
                deviceModel: Self.machineIdentifier(), gpu: renderer.device.name, simulator: simulator,
                protocolName: quick ? "smoke / 1 repeat" : "standard / 5 repeats",
                buildConfiguration: buildConfiguration,
                preIdleSeconds: duration.pre, interactionSeconds: duration.interaction, idleSeconds: duration.idle)
            do {
                status = "Preparing codec measurements…"
                report.codec = try await Task.detached(priority: .userInitiated) {
                    var rows: [CodecMeasurement] = []
                    for count in [10_000, 50_000, 100_000] {
                        for kind in DatasetKind.allCases {
                            rows += try CodecBenchmark.run(dots: Dataset.make(count: count, kind: kind),
                                                           dataset: kind, repeats: quick ? 3 : 20)
                        }
                    }
                    return rows
                }.value
                codecRows = report.codec.filter { $0.count == self.count && $0.dataset == .orbital }
                var trials = (0..<(quick ? 1 : 5)).flatMap { repeatIndex in
                    [10_000, 50_000, 100_000].flatMap { count in
                        SimulationMode.allCases.map { (count, $0, repeatIndex) }
                    }
                }
                var random = SplitMix64(state: 82)
                for i in stride(from: trials.count - 1, through: 1, by: -1) {
                    trials.swapAt(i, Int(random.next() % UInt64(i + 1)))
                }
                for (index, trial) in trials.enumerated() {
                    try Task.checkCancellation()
                    count = trial.0; mode = trial.1
                    status = "Trial \(index + 1)/\(trials.count) · \(count.formatted()) · \(mode.label)"
                    let thermalStart = ProcessInfo.processInfo.thermalState.rawValue
                    renderer.phase = .warmup
                    try renderer.reset(dots: Dataset.make(count: count), mode: mode)
                    try await Task.sleep(for: .seconds(1))
                    try await phase(.preIdle, seconds: duration.pre, renderer: renderer)
                    renderer.scriptStart = CACurrentMediaTime()
                    try await phase(.interaction, seconds: duration.interaction, renderer: renderer)
                    renderer.scriptStart = nil
                    renderer.phase = .settling
                    os_signpost(.begin, log: logger, name: "settling")
                    let settleStart = CACurrentMediaTime()
                    while renderer.simulation.hasActivity && CACurrentMediaTime() - settleStart < 10 {
                        try await Task.sleep(for: .milliseconds(50))
                    }
                    os_signpost(.end, log: logger, name: "settling")
                    let settleSeconds = CACurrentMediaTime() - settleStart
                    let settled = !renderer.simulation.hasActivity
                    try await phase(.idle, seconds: duration.idle, renderer: renderer)
                    renderer.view?.isPaused = true
                    // Let the last GPU completion reach the main actor before snapshotting.
                    try await Task.sleep(for: .milliseconds(100))
                    let raw = Dictionary(uniqueKeysWithValues: renderer.samples.map { ($0.key.rawValue, $0.value) })
                    report.trials.append(DeviceTrial(count: count, mode: mode, repeatIndex: trial.2,
                        phases: raw.mapValues(PhaseSummary.init), rawSamples: raw, settled: settled,
                        settleSeconds: settleSeconds, readyToSubmitFirstFrameMS: renderer.firstFrameMS,
                        residentBytes: Self.residentBytes(), thermalStart: thermalStart,
                        thermalEnd: ProcessInfo.processInfo.thermalState.rawValue, metalError: renderer.lastError))
                    completedTrials = index + 1; progress = Double(index + 1) / Double(trials.count)
                    exportURL = try Self.save(report)
                }
                report.completed = true
                exportURL = try Self.save(report)
                status = "Complete · \(report.trials.count) trials saved."
            } catch {
                report.interruption = String(describing: error)
                exportURL = try? Self.save(report)
                status = "Stopped · partial results saved."
            }
            refreshStats()
        }
    }

    private func phase(_ phase: RunPhase, seconds: Double, renderer: ParticleRenderer) async throws {
        renderer.phase = phase
        os_signpost(.begin, log: logger, name: "benchmark phase", "%{public}s", phase.rawValue)
        defer { os_signpost(.end, log: logger, name: "benchmark phase") }
        try await Task.sleep(for: .seconds(seconds))
    }

    private static func save(_ report: DeviceReport) throws -> URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let name = report.protocolName.hasPrefix("smoke") ? "device-smoke.json" : "device-standard.json"
        let url = folder.appendingPathComponent(name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: url, options: .atomic)
        return url
    }

    private static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        let size = MemoryLayout.size(ofValue: info.machine)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: size) {
                String(cString: $0)
            }
        }
    }

    private static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}
