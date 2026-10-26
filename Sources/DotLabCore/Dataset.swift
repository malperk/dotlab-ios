import Foundation

public struct Dot: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var radius: Float

    public init(x: Float, y: Float, radius: Float) {
        self.x = x
        self.y = y
        self.radius = radius
    }
}

public enum DatasetKind: String, CaseIterable, Codable, Sendable {
    case orbital, uniform
}

/// Stable generator: identical input order and values on every run.
public enum Dataset {
    public static func make(count: Int, kind: DatasetKind = .orbital, seed: UInt64 = 103_802) -> [Dot] {
        precondition(count >= 0)
        var random = SplitMix64(state: seed)
        return (0..<count).map { index in
            let u = random.unit()
            let v = random.unit()
            let w = random.unit()
            if kind == .uniform {
                return Dot(x: u, y: v, radius: 0.0006 + w * 0.0012)
            }
            let ring = Float(index % 31) / 30
            let angle = u * 2 * .pi
            let wave = sin(angle * 3 + ring * 5) * 0.025
            let radius = 0.07 + ring * 0.31 + wave + (v - 0.5) * 0.005
            return Dot(
                x: 0.5 + cos(angle) * radius,
                y: 0.5 + sin(angle) * radius,
                radius: 0.0006 + w * 0.0012
            )
        }
    }
}

public struct SplitMix64: Sendable {
    public var state: UInt64
    public init(state: UInt64) { self.state = state }
    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
    public mutating func unit() -> Float { Float(next() >> 40) / 16_777_216 }
}
