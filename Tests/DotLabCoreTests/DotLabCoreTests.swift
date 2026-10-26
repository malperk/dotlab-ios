import Foundation
import Testing
@testable import DotLabCore

@Test func floatRoundTripIsLossless() throws {
    let dots = Dataset.make(count: 1038)
    #expect(try DotCodec.decode(DotCodec.encode(dots, format: .floatInterleaved)) == dots)
}

@Test func quantizedLayoutsAgreeAndRespectErrorBounds() throws {
    let dots = Dataset.make(count: 2000) + [Dot(x: 0, y: 1, radius: 0), Dot(x: 1, y: 0, radius: 0.004)]
    let reference = try DotCodec.decode(DotCodec.encode(dots, format: .quantizedInterleaved))
    for format in [DotFormat.quantizedInterleaved, .quantizedPlanar, .deltaPlanar] {
        let encoded = try DotCodec.encode(dots, format: format)
        #expect(encoded.count == 16 + dots.count * 5)
        let decoded = try DotCodec.decode(encoded)
        #expect(decoded == reference)
        for (a, b) in zip(dots, decoded) {
            #expect(abs(a.x - b.x) <= 0.5 / 65_535 + 1e-7)
            #expect(abs(a.y - b.y) <= 0.5 / 65_535 + 1e-7)
            #expect(abs(a.radius - b.radius) <= 0.004 / 510 + 1e-8)
        }
        #expect(try DotCodec.decompress(DotCodec.compress(encoded), expectedSize: encoded.count) == encoded)
    }
}

@Test func rejectsMalformedData() throws {
    let valid = try DotCodec.encode(Dataset.make(count: 3), format: .deltaPlanar)
    for size in 0..<valid.count {
        #expect(throws: (any Error).self) { try DotCodec.decode(Data(valid.prefix(size))) }
    }
    var invalid = valid
    invalid[4] = 255
    #expect(throws: CodecError.unsupportedVersion) { try DotCodec.decode(invalid) }
    invalid = valid
    invalid[8] = 255; invalid[9] = 255; invalid[10] = 255; invalid[11] = 255
    #expect(throws: CodecError.invalidLength) { try DotCodec.decode(invalid) }
    #expect(throws: CodecError.invalidValue) {
        try DotCodec.encode([Dot(x: .nan, y: 0, radius: 0)], format: .floatInterleaved)
    }
    let compressed = try DotCodec.compress(valid)
    #expect(throws: (any Error).self) { try DotCodec.decompress(compressed, expectedSize: valid.count - 1) }
    #expect(throws: (any Error).self) { try DotCodec.decompress(Data([0, 1, 2]), expectedSize: valid.count) }
}

@Test func emptyDatasetRoundTrips() throws {
    for format in DotFormat.allCases {
        let raw = try DotCodec.encode([], format: format)
        #expect(try DotCodec.decode(raw).isEmpty)
        #expect(try DotCodec.decompress(DotCodec.compress(raw), expectedSize: raw.count) == raw)
    }
}

@Test func activeModesMatchFullScanAndSettle() {
    let dots = Dataset.make(count: 2000)
    let simulations = SimulationMode.allCases.map { Simulation(dots: dots, mode: $0) }
    for step in 0..<240 {
        let touch = InteractionScript.point(seconds: Double(step) / 120)
        for simulation in simulations { simulation.update(touch: touch) }
    }
    for i in dots.indices {
        for simulation in simulations.dropFirst() {
            #expect(simulation.position(at: i) == simulations[0].position(at: i))
        }
    }
    for simulation in simulations {
        for _ in 0..<1200 where simulation.hasActivity { simulation.update(touch: nil) }
        #expect(!simulation.hasActivity)
        for i in dots.indices { #expect(simulation.position(at: i) == SIMD2(dots[i].x, dots[i].y)) }
    }
}

@Test func gridMatchesScanAtEdgesAndCenter() {
    let dots = Dataset.make(count: 1000, kind: .uniform) + [Dot(x: 0.5, y: 0.5, radius: 0.001)]
    let scan = Simulation(dots: dots, mode: .sleep)
    let grid = Simulation(dots: dots, mode: .activeSoA)
    for touch in [SIMD2<Float>(0, 0), SIMD2(1, 1), SIMD2(0.5, 0.5), SIMD2(-0.1, 0.5)] {
        scan.update(touch: touch); grid.update(touch: touch)
        for i in dots.indices { #expect(scan.position(at: i) == grid.position(at: i)) }
    }
}

@Test func stationaryActiveSimulationDoesNoWork() {
    let simulation = Simulation(dots: Dataset.make(count: 1000), mode: .activeAoS)
    let work = simulation.update(touch: nil)
    #expect(work.updated == 0)
    #expect(work.hitTests == 0)
    #expect(!simulation.hasActivity)
}
