import Foundation

public enum Statistics {
    public static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, max(0, Int(ceil(p * Double(sorted.count))) - 1))
        return sorted[index]
    }
    public static func milliseconds() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000
    }
}

public struct CodecMeasurement: Codable, Sendable {
    public var dataset: DatasetKind
    public var count: Int
    public var format: DotFormat
    public var rawBytes: Int
    public var compressedBytes: Int
    public var decompressP50MS: Double
    public var decodeP50MS: Double
    public var totalP50MS: Double
    public var totalP95MS: Double
    public var maxPositionErrorPixels: Double
    public var maxRadiusErrorPixels: Double
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var repeats: Int
}

public enum CodecBenchmark {
    /// All variants decode into the SAME [Dot] runtime layout. The source, order,
    /// compressor, viewport, and sample count stay fixed.
    public static func run(dots: [Dot], dataset: DatasetKind, repeats: Int = 10,
                           pixelWidth: Int = 1179, pixelHeight: Int = 1179) throws -> [CodecMeasurement] {
        precondition(repeats > 0)
        var rows: [CodecMeasurement] = []
        for format in DotFormat.allCases {
            let raw = try DotCodec.encode(dots, format: format)
            let compressed = try DotCodec.compress(raw)
            let decoded = try DotCodec.decode(try DotCodec.decompress(compressed, expectedSize: raw.count))
            var maxPosition = 0.0
            var maxRadius = 0.0
            for (source, target) in zip(dots, decoded) {
                let dx = Double(source.x - target.x) * Double(pixelWidth)
                let dy = Double(source.y - target.y) * Double(pixelHeight)
                maxPosition = max(maxPosition, hypot(dx, dy))
                maxRadius = max(maxRadius, Double(abs(source.radius - target.radius)) * Double(pixelWidth))
            }
            var decompressionTimes: [Double] = []
            var decodeTimes: [Double] = []
            var totalTimes: [Double] = []
            for _ in 0..<repeats {
                let start = Statistics.milliseconds()
                let uncompressed = try DotCodec.decompress(compressed, expectedSize: raw.count)
                let middle = Statistics.milliseconds()
                let result = try DotCodec.decode(uncompressed)
                let end = Statistics.milliseconds()
                guard result.count == dots.count else { throw CodecError.invalidLength }
                decompressionTimes.append(middle - start)
                decodeTimes.append(end - middle)
                totalTimes.append(end - start)
            }
            rows.append(CodecMeasurement(dataset: dataset, count: dots.count, format: format,
                rawBytes: raw.count, compressedBytes: compressed.count,
                decompressP50MS: Statistics.percentile(decompressionTimes, 0.5),
                decodeP50MS: Statistics.percentile(decodeTimes, 0.5),
                totalP50MS: Statistics.percentile(totalTimes, 0.5),
                totalP95MS: Statistics.percentile(totalTimes, 0.95),
                maxPositionErrorPixels: maxPosition, maxRadiusErrorPixels: maxRadius,
                pixelWidth: pixelWidth, pixelHeight: pixelHeight, repeats: repeats))
        }
        return rows
    }
}

public struct EnvironmentInfo: Codable, Sendable {
    public var platform: String
    public var os: String
    public var processorCount: Int
    public var timestamp: String
    public var notes: String
    public init(platform: String, notes: String) {
        self.platform = platform
        os = ProcessInfo.processInfo.operatingSystemVersionString
        processorCount = ProcessInfo.processInfo.processorCount
        timestamp = ISO8601DateFormatter().string(from: Date())
        self.notes = notes
    }
}

public struct SimulationMeasurement: Codable, Sendable {
    public var count: Int
    public var mode: SimulationMode
    public var repeatIndex: Int
    public var updateP50MS: Double
    public var updateP95MS: Double
    public var totalUpdated: Int
    public var totalHitTests: Int
    public var settleSteps: Int
    public var settled: Bool
    public var checksum: Double
}

public enum SimulationBenchmark {
    /// Headless CPU microbenchmark; NOT a frame-rate, GPU, or energy measurement.
    public static func run(count: Int, mode: SimulationMode, repeatIndex: Int,
                           interactionSteps: Int = 1200, maxSettleSteps: Int = 1200) -> SimulationMeasurement {
        let simulation = Simulation(dots: Dataset.make(count: count), mode: mode)
        var times: [Double] = []
        var updated = 0
        var hitTests = 0
        for step in 0..<interactionSteps {
            let touch = InteractionScript.point(seconds: Double(step) / 120)
            let start = Statistics.milliseconds()
            let work = simulation.update(touch: touch)
            times.append(Statistics.milliseconds() - start)
            updated += work.updated
            hitTests += work.hitTests
        }
        var settleSteps = 0
        while simulation.hasActivity && settleSteps < maxSettleSteps {
            let work = simulation.update(touch: nil)
            updated += work.updated
            settleSteps += 1
        }
        var checksum = 0.0
        for i in 0..<count { checksum += Double(simulation.position(at: i).x) }
        return SimulationMeasurement(count: count, mode: mode, repeatIndex: repeatIndex,
            updateP50MS: Statistics.percentile(times, 0.5),
            updateP95MS: Statistics.percentile(times, 0.95), totalUpdated: updated,
            totalHitTests: hitTests, settleSteps: settleSteps, settled: !simulation.hasActivity,
            checksum: checksum)
    }
}
