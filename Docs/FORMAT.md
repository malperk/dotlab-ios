# DLAB v1 binary format

All multibyte fields are little-endian. Files represent uncompressed payloads; LZFSE is an outer transport/storage layer. Callers must keep the expected decoded byte count alongside compressed data. This experiment does not implement a network service.

## Header

| Offset | Bytes | Meaning |
|---:|---:|---|
| 0 | 4 | ASCII `DLAB` |
| 4 | 1 | Version `1` |
| 5 | 1 | Format ID `0`–`3` |
| 6 | 2 | Reserved, must be zero |
| 8 | 4 | Dot count as UInt32, maximum 1,000,000 |
| 12 | 4 | Float32 radius scale, exactly `0.004` in v1 |

## Payloads

**0 — Float32 interleaved:** `[x:f32, y:f32, radius:f32]` repeated `count` times. Exactly `16 + count×12` bytes.

**1 — Quantized interleaved:** `[x:u16, y:u16, radius:u8]` repeated `count` times. Exactly `16 + count×5` bytes.

**2 — Quantized planar:** `count` UInt16 X values, `count` UInt16 Y values, then `count` UInt8 radius values. Same size as format 1.

**3 — Quantized planar with deltas:** same blocks as format 2. Each block starts with a zero predictor. Store `current &- previous` and decode with `previous &+ stored`, using the field's unsigned bit width. Wrapping handles negative differences without an additional sign byte. The first encoded element is absolute. Deltas do not imply sorting or spatial locality.

## Quantization

```text
xEncoded = round(x × 65535)
yEncoded = round(y × 65535)
rEncoded = round(radius / 0.004 × 255)

xDecoded = xEncoded / 65535
yDecoded = yEncoded / 65535
rDecoded = rEncoded / 255 × 0.004
```

Coordinates must be finite in `[0,1]`; radius must be finite in `[0,0.004]`. Values outside the range are rejected rather than silently clamped. Decoded values are Float32, which does not restore precision lost during quantization.

Ignoring Float32 rounding, maximum per-axis coordinate error is `0.5/65535`. At 1179×1179 pixels, maximum Euclidean position error is about 0.01272 pixels. Maximum radius error is approximately `1179×0.004/510`, or 0.00925 pixels. Radius is defined relative to view width, matching the shader.

## Validation

The decoder rejects unknown versions/formats, nonzero reserved fields, unexpected radius scales, excessive counts, truncated/extra payload bytes, and nonfinite/out-of-range Float32 payload values. Bytewise reads avoid alignment assumptions. Raw Swift memory layout is never serialized.

Decompression rejects an empty compressed input, unreasonable declared output sizes, failed decoding, and output shorter or longer than the expected size. This is an experimental format without a checksum/authentication envelope; use integrity/authentication at the transport layer for production distribution.
