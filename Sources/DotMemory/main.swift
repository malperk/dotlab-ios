import Darwin
import DotLabCore
import Foundation

func residentBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return status == KERN_SUCCESS ? info.resident_size : 0
}

struct MemorySample: Codable {
    var baselineResidentBytes: UInt64
    var peakProcessResidentBytes: Int64
    var finalResidentBytes: UInt64
    var decodedCount: Int
    var checksum: Double
}

func emitSample(baseline: UInt64, count: Int, checksum: Double) throws {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let sample = MemorySample(baselineResidentBytes: baseline,
        peakProcessResidentBytes: Int64(usage.ru_maxrss), finalResidentBytes: residentBytes(),
        decodedCount: count, checksum: checksum)
    let data = try JSONEncoder().encode(sample)
    print(String(decoding: data, as: UTF8.self))
}

do {
    if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--simulate",
       let mode = SimulationMode(rawValue: CommandLine.arguments[2]),
       let count = Int(CommandLine.arguments[3]), [10_000, 50_000, 100_000].contains(count) {
        let baseline = residentBytes()
        let dots = Dataset.make(count: count)
        let simulation = Simulation(dots: dots, mode: mode)
        for step in 0..<240 {
            simulation.update(touch: InteractionScript.point(seconds: Double(step) / 120))
        }
        var checksum = 0.0
        for index in 0..<count { checksum += Double(simulation.position(at: index).x) }
        try withExtendedLifetime((dots, simulation)) {
            try emitSample(baseline: baseline, count: count, checksum: checksum)
        }
        exit(0)
    }
    guard CommandLine.arguments.count == 3,
          let expectedSize = Int(CommandLine.arguments[2]) else {
        throw NSError(domain: "Usage: dotmemory fixture.lzfse rawByteCount", code: 1)
    }
    let baseline = residentBytes()
    let compressed = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let uncompressed = try DotCodec.decompress(compressed, expectedSize: expectedSize)
    let dots = try DotCodec.decode(uncompressed)
    let checksum = dots.reduce(0.0) { $0 + Double($1.x) }
    // Keep all client-side stages alive until after the peak/final sample.
    try withExtendedLifetime((compressed, uncompressed, dots)) {
        try emitSample(baseline: baseline, count: dots.count, checksum: checksum)
    }
} catch {
    fputs("dotmemory: \(error)\n", stderr)
    exit(1)
}
