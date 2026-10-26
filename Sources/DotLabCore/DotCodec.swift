import Compression
import Foundation

public enum DotFormat: UInt8, CaseIterable, Codable, Sendable {
    case floatInterleaved = 0
    case quantizedInterleaved = 1
    case quantizedPlanar = 2
    case deltaPlanar = 3

    public var label: String {
        switch self {
        case .floatInterleaved: "Float32 / interleaved"
        case .quantizedInterleaved: "Quantized / interleaved"
        case .quantizedPlanar: "Quantized / planar"
        case .deltaPlanar: "Quantized / planar + delta"
        }
    }
}

public enum CodecError: Error, Equatable {
    case invalidHeader, unsupportedVersion, invalidLength, invalidValue, compressionFailed
}

/// DLAB v1: explicit little-endian bytes. No Swift struct padding enters the file.
/// Header: magic(4), version(1), format(1), reserved(2), count(4), radiusScale(Float32,4).
public enum DotCodec {
    public static let headerSize = 16
    public static let radiusScale: Float = 0.004
    public static let maxCount = 1_000_000

    public static func encode(_ dots: [Dot], format: DotFormat) throws -> Data {
        guard dots.count <= maxCount else { throw CodecError.invalidLength }
        guard dots.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.radius.isFinite &&
            (0...1).contains($0.x) && (0...1).contains($0.y) &&
            (0...radiusScale).contains($0.radius) }) else { throw CodecError.invalidValue }
        var bytes: [UInt8] = [68, 76, 65, 66, 1, format.rawValue, 0, 0]
        append32(UInt32(dots.count), to: &bytes)
        append32(radiusScale.bitPattern, to: &bytes)
        bytes.reserveCapacity(headerSize + dots.count * (format == .floatInterleaved ? 12 : 5))
        func quantize(_ value: Float) -> UInt16 { UInt16((value * 65_535).rounded()) }
        func quantizeRadius(_ value: Float) -> UInt8 { UInt8((value / radiusScale * 255).rounded()) }
        switch format {
        case .floatInterleaved:
            for dot in dots {
                append32(dot.x.bitPattern, to: &bytes)
                append32(dot.y.bitPattern, to: &bytes)
                append32(dot.radius.bitPattern, to: &bytes)
            }
        case .quantizedInterleaved:
            for dot in dots {
                append16(quantize(dot.x), to: &bytes)
                append16(quantize(dot.y), to: &bytes)
                bytes.append(quantizeRadius(dot.radius))
            }
        case .quantizedPlanar, .deltaPlanar:
            for axis in [\Dot.x, \Dot.y] {
                var previous: UInt16 = 0
                for dot in dots {
                    let value = quantize(dot[keyPath: axis])
                    append16(format == .deltaPlanar ? value &- previous : value, to: &bytes)
                    previous = value
                }
            }
            var previous: UInt8 = 0
            for dot in dots {
                let value = quantizeRadius(dot.radius)
                bytes.append(format == .deltaPlanar ? value &- previous : value)
                previous = value
            }
        }
        return Data(bytes)
    }

    public static func decode(_ data: Data) throws -> [Dot] {
        let bytes = [UInt8](data)
        guard bytes.count >= headerSize, Array(bytes[0..<4]) == [68, 76, 65, 66] else {
            throw CodecError.invalidHeader
        }
        guard bytes[4] == 1 else { throw CodecError.unsupportedVersion }
        guard let format = DotFormat(rawValue: bytes[5]), bytes[6] == 0, bytes[7] == 0 else {
            throw CodecError.invalidHeader
        }
        let count = Int(read32(bytes, 8))
        let scale = Float(bitPattern: read32(bytes, 12))
        guard scale == radiusScale else { throw CodecError.invalidHeader }
        guard count <= maxCount,
              bytes.count == headerSize + count * (format == .floatInterleaved ? 12 : 5) else {
            throw CodecError.invalidLength
        }
        var dots = [Dot](repeating: Dot(x: 0, y: 0, radius: 0), count: count)
        switch format {
        case .floatInterleaved:
            for i in 0..<count {
                let start = headerSize + i * 12
                dots[i] = Dot(x: Float(bitPattern: read32(bytes, start)),
                              y: Float(bitPattern: read32(bytes, start + 4)),
                              radius: Float(bitPattern: read32(bytes, start + 8)))
            }
        case .quantizedInterleaved:
            for i in 0..<count {
                let start = headerSize + i * 5
                dots[i] = Dot(x: Float(read16(bytes, start)) / 65_535,
                              y: Float(read16(bytes, start + 2)) / 65_535,
                              radius: Float(bytes[start + 4]) / 255 * scale)
            }
        case .quantizedPlanar, .deltaPlanar:
            for (axisIndex, axis) in [\Dot.x, \Dot.y].enumerated() {
                var previous: UInt16 = 0
                for i in 0..<count {
                    let encoded = read16(bytes, headerSize + axisIndex * count * 2 + i * 2)
                    let value = format == .deltaPlanar ? previous &+ encoded : encoded
                    dots[i][keyPath: axis] = Float(value) / 65_535
                    previous = value
                }
            }
            var previous: UInt8 = 0
            for i in 0..<count {
                let encoded = bytes[headerSize + count * 4 + i]
                let value = format == .deltaPlanar ? previous &+ encoded : encoded
                dots[i].radius = Float(value) / 255 * scale
                previous = value
            }
        }
        guard dots.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.radius.isFinite &&
            (0...1).contains($0.x) && (0...1).contains($0.y) &&
            (0...scale).contains($0.radius) }) else { throw CodecError.invalidValue }
        return dots
    }

    public static func compress(_ data: Data) throws -> Data {
        let capacity = data.count + max(4096, data.count / 8)
        var output = [UInt8](repeating: 0, count: capacity)
        let size = data.withUnsafeBytes { source in
            compression_encode_buffer(&output, capacity, source.bindMemory(to: UInt8.self).baseAddress!,
                                      data.count, nil, COMPRESSION_LZFSE)
        }
        guard size > 0 else { throw CodecError.compressionFailed }
        return Data(output.prefix(size))
    }

    public static func decompress(_ data: Data, expectedSize: Int) throws -> Data {
        guard !data.isEmpty, expectedSize >= headerSize,
              expectedSize <= headerSize + maxCount * 12 else { throw CodecError.invalidLength }
        // One extra byte detects output that exceeds the declared uncompressed size.
        var output = [UInt8](repeating: 0, count: expectedSize + 1)
        let size = data.withUnsafeBytes { source in
            compression_decode_buffer(&output, output.count, source.bindMemory(to: UInt8.self).baseAddress!,
                                      data.count, nil, COMPRESSION_LZFSE)
        }
        guard size == expectedSize else { throw CodecError.compressionFailed }
        return Data(output.prefix(size))
    }

    private static func append16(_ value: UInt16, to bytes: inout [UInt8]) {
        bytes.append(UInt8(truncatingIfNeeded: value))
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
    }
    private static func append32(_ value: UInt32, to bytes: inout [UInt8]) {
        for shift in stride(from: 0, to: 32, by: 8) { bytes.append(UInt8(truncatingIfNeeded: value >> shift)) }
    }
    private static func read16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }
    private static func read32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 |
        UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
}
