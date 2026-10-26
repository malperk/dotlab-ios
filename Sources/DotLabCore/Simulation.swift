import Foundation

public enum SimulationMode: String, CaseIterable, Codable, Sendable {
    case continuous, sleep, activeAoS, activeSoA
    public var label: String {
        switch self {
        case .continuous: "R0 · Always on"
        case .sleep: "R1 · Sleep when settled"
        case .activeAoS: "R2 · Active / AoS"
        case .activeSoA: "R3 · Active / SoA"
        }
    }
    public var usesActiveSet: Bool { self == .activeAoS || self == .activeSoA }
}

private struct Particle {
    var x: Float
    var y: Float
    var vx: Float = 0
    var vy: Float = 0
}

public struct StepWork: Codable, Sendable {
    public var updated = 0
    public var hitTests = 0
}

/// The interaction field is defined in REST coordinates. A static home-position
/// grid therefore finds exactly the same affected dots as a full scan.
public final class Simulation {
    public let homes: [Dot]
    public let mode: SimulationMode
    private var particles: [Particle]
    private var x: [Float]
    private var y: [Float]
    private var vx: [Float]
    private var vy: [Float]
    private var homeX: [Float]
    private var homeY: [Float]
    private var active: [Int] = []
    private var isActive: [Bool]
    private let gridSize = 16
    private var grid: [[Int]]
    public private(set) var activeCount = 0
    public var hasActivity: Bool { activeCount > 0 }
    public static let step: Float = 1 / 120
    public static let interactionRadius: Float = 0.16

    public init(dots: [Dot], mode: SimulationMode) {
        self.homes = dots
        self.mode = mode
        particles = mode == .activeSoA ? [] : dots.map { Particle(x: $0.x, y: $0.y) }
        x = mode == .activeSoA ? dots.map(\.x) : []
        y = mode == .activeSoA ? dots.map(\.y) : []
        vx = mode == .activeSoA ? [Float](repeating: 0, count: dots.count) : []
        vy = vx
        homeX = mode == .activeSoA ? dots.map(\.x) : []
        homeY = mode == .activeSoA ? dots.map(\.y) : []
        isActive = [Bool](repeating: false, count: dots.count)
        grid = [[Int]](repeating: [], count: gridSize * gridSize)
        active.reserveCapacity(dots.count)
        for (i, dot) in dots.enumerated() {
            let column = min(gridSize - 1, max(0, Int(dot.x * Float(gridSize))))
            let row = min(gridSize - 1, max(0, Int(dot.y * Float(gridSize))))
            grid[row * gridSize + column].append(i)
        }
    }

    @discardableResult
    public func update(touch: SIMD2<Float>?) -> StepWork {
        var work = StepWork()
        if let touch {
            if mode.usesActiveSet {
                let r = Self.interactionRadius
                let left = max(0, min(gridSize - 1, Int(floor((touch.x - r) * Float(gridSize)))))
                let right = max(0, min(gridSize - 1, Int(floor((touch.x + r) * Float(gridSize)))))
                let top = max(0, min(gridSize - 1, Int(floor((touch.y - r) * Float(gridSize)))))
                let bottom = max(0, min(gridSize - 1, Int(floor((touch.y + r) * Float(gridSize)))))
                for row in top...bottom {
                    for column in left...right {
                        for index in grid[row * gridSize + column] {
                            work.hitTests += 1
                            applyTouch(touch, index: index)
                        }
                    }
                }
            } else {
                for index in homes.indices {
                    work.hitTests += 1
                    applyTouch(touch, index: index)
                }
            }
        }
        if mode.usesActiveSet {
            var cursor = 0
            while cursor < active.count {
                let index = active[cursor]
                work.updated += 1
                if integrate(index) {
                    cursor += 1
                } else {
                    isActive[index] = false
                    active.swapAt(cursor, active.count - 1)
                    active.removeLast()
                }
            }
            activeCount = active.count
        } else {
            activeCount = 0
            for index in homes.indices {
                work.updated += 1
                isActive[index] = integrate(index)
                if isActive[index] { activeCount += 1 }
            }
        }
        return work
    }

    private func applyTouch(_ touch: SIMD2<Float>, index i: Int) {
        let dx = homes[i].x - touch.x
        let dy = homes[i].y - touch.y
        let distanceSquared = dx * dx + dy * dy
        let r = Self.interactionRadius
        guard distanceSquared < r * r else { return }
        let distance = max(sqrt(distanceSquared), 0.0001)
        let force = (1 - distance / r) * 5 * Self.step
        if mode == .activeSoA {
            vx[i] += dx / distance * force
            vy[i] += dy / distance * force
        } else {
            particles[i].vx += dx / distance * force
            particles[i].vy += dy / distance * force
        }
        if mode.usesActiveSet && !isActive[i] {
            isActive[i] = true
            active.append(i)
        }
    }

    /// Semi-implicit Euler, identical math/order for both memory layouts.
    private func integrate(_ i: Int) -> Bool {
        let soa = mode == .activeSoA
        let hx = soa ? homeX[i] : homes[i].x
        let hy = soa ? homeY[i] : homes[i].y
        let px = soa ? x[i] : particles[i].x
        let py = soa ? y[i] : particles[i].y
        let oldVX = soa ? vx[i] : particles[i].vx
        let oldVY = soa ? vy[i] : particles[i].vy
        let nextVX = oldVX + ((hx - px) * 60 - oldVX * 12) * Self.step
        let nextVY = oldVY + ((hy - py) * 60 - oldVY * 12) * Self.step
        var nextX = px + nextVX * Self.step
        var nextY = py + nextVY * Self.step
        let dx = nextX - hx
        let dy = nextY - hy
        let moving = dx * dx + dy * dy >= 1e-9 || nextVX * nextVX + nextVY * nextVY >= 1e-7
        if !moving { nextX = hx; nextY = hy }
        if soa {
            x[i] = nextX; y[i] = nextY
            vx[i] = moving ? nextVX : 0; vy[i] = moving ? nextVY : 0
        } else {
            particles[i] = Particle(x: nextX, y: nextY,
                                    vx: moving ? nextVX : 0, vy: moving ? nextVY : 0)
        }
        return moving
    }

    public func position(at i: Int) -> SIMD2<Float> {
        mode == .activeSoA ? SIMD2(x[i], y[i]) : SIMD2(particles[i].x, particles[i].y)
    }

    /// All modes upload the same Float32 render layout. Writing to a caller-owned
    /// buffer avoids per-frame Swift allocations. Radius is normalized to width.
    public func writeVertices(to output: UnsafeMutableBufferPointer<SIMD4<Float>>) {
        precondition(output.count >= homes.count)
        for i in homes.indices {
            let position = position(at: i)
            let dx = position.x - homes[i].x
            let dy = position.y - homes[i].y
            output[i] = SIMD4(position.x, position.y, homes[i].radius, min(1, sqrt(dx * dx + dy * dy) * 10))
        }
    }
}

public enum InteractionScript {
    public static func point(seconds: Double) -> SIMD2<Float> {
        let t = Float(seconds)
        return SIMD2(0.5 + cos(t * 1.7) * 0.25, 0.5 + sin(t * 2.3) * 0.22)
    }
}
