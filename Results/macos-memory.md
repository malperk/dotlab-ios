# DotLab decoding memory

Recorded: 2026-10-26T12:48:20.681295+00:00

macOS-27.0.1-arm64-arm-64bit-Mach-O

Release macOS decoding-only probe. Every sample is a fresh process. ru_maxrss is the whole-process resident high-water mark in Darwin bytes, including Swift/Foundation and file reading. Compressed input, uncompressed payload, and decoded Float32 dots remain alive at the final sample. No generator, encoder, renderer, or GPU buffers run in the child. Filesystem cache and allocator behavior affect results. Baseline RSS is not subtracted from the peak; that difference would not isolate allocator peaks.

Medians across independent processes. MiB = 1,048,576 bytes. Peaks include process startup.

| Dataset | Dots | Format | Repeats | Baseline RSS (MiB) | Peak process RSS (MiB) | Final RSS (MiB) |
|---|---:|---|---:|---:|---:|---:|
| orbital | 10,000 | Float32 interleaved | 5 | 5.73 | 6.38 | 6.38 |
| orbital | 10,000 | Quantized interleaved | 5 | 5.73 | 6.20 | 6.20 |
| orbital | 10,000 | Quantized planar | 5 | 5.73 | 6.20 | 6.20 |
| orbital | 10,000 | Quantized planar + delta | 5 | 5.73 | 6.22 | 6.22 |
| orbital | 50,000 | Float32 interleaved | 5 | 5.73 | 8.16 | 8.16 |
| orbital | 50,000 | Quantized interleaved | 5 | 5.73 | 7.22 | 7.22 |
| orbital | 50,000 | Quantized planar | 5 | 5.73 | 7.22 | 7.22 |
| orbital | 50,000 | Quantized planar + delta | 5 | 5.73 | 7.23 | 7.23 |
| orbital | 100,000 | Float32 interleaved | 5 | 5.73 | 10.41 | 10.41 |
| orbital | 100,000 | Quantized interleaved | 5 | 5.73 | 8.50 | 8.50 |
| orbital | 100,000 | Quantized planar | 5 | 5.73 | 8.50 | 8.50 |
| orbital | 100,000 | Quantized planar + delta | 5 | 5.73 | 8.52 | 8.52 |
| uniform | 10,000 | Float32 interleaved | 5 | 5.73 | 6.38 | 6.38 |
| uniform | 10,000 | Quantized interleaved | 5 | 5.73 | 6.20 | 6.20 |
| uniform | 10,000 | Quantized planar | 5 | 5.73 | 6.20 | 6.20 |
| uniform | 10,000 | Quantized planar + delta | 5 | 5.73 | 6.22 | 6.22 |
| uniform | 50,000 | Float32 interleaved | 5 | 5.73 | 8.16 | 8.16 |
| uniform | 50,000 | Quantized interleaved | 5 | 5.73 | 7.22 | 7.22 |
| uniform | 50,000 | Quantized planar | 5 | 5.73 | 7.22 | 7.22 |
| uniform | 50,000 | Quantized planar + delta | 5 | 5.73 | 7.23 | 7.23 |
| uniform | 100,000 | Float32 interleaved | 5 | 5.73 | 10.42 | 10.42 |
| uniform | 100,000 | Quantized interleaved | 5 | 5.75 | 8.52 | 8.52 |
| uniform | 100,000 | Quantized planar | 5 | 5.73 | 8.50 | 8.50 |
| uniform | 100,000 | Quantized planar + delta | 5 | 5.73 | 8.55 | 8.55 |

## Simulation process memory

Optional simulation samples each use a fresh process, the orbital generator, and 240 identical scripted steps. Source, simulation storage, spatial grid, and active membership are alive at sampling. No render buffers or GPU work. SoA currently duplicates immutable home X/Y into planar arrays while keeping the shared source dots for interaction/rendering. This is a measured implementation choice, not a memory cost intrinsic to every SoA design.

| Dots | Mode | Repeats | Peak process RSS (MiB) | Final RSS (MiB) |
|---:|---|---:|---:|---:|
| 10,000 | activeAoS | 5 | 6.44 | 6.44 |
| 10,000 | activeSoA | 5 | 6.56 | 6.56 |
| 10,000 | continuous | 5 | 6.41 | 6.41 |
| 10,000 | sleep | 5 | 6.41 | 6.41 |
| 50,000 | activeAoS | 5 | 8.34 | 8.34 |
| 50,000 | activeSoA | 5 | 8.80 | 8.80 |
| 50,000 | continuous | 5 | 8.14 | 8.14 |
| 50,000 | sleep | 5 | 8.14 | 8.14 |
| 100,000 | activeAoS | 5 | 10.73 | 10.73 |
| 100,000 | activeSoA | 5 | 11.56 | 11.56 |
| 100,000 | continuous | 5 | 10.33 | 10.33 |
| 100,000 | sleep | 5 | 10.33 | 10.33 |
