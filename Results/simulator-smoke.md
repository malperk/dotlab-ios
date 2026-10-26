# DotLab benchmark results

Recorded: 2026-10-26T12:32:42Z

Platform: iOS · Version 27.0 (Build 24A434)

Release build required for interpretation. Metal instanced quads; CPU fixed-step physics. Submission times are elapsed wall time including drawable/semaphore waits, not process CPU utilization. GPU execution is command-buffer time, not display latency. Missed refreshes are estimates from callback spacing. RSS is a post-trial snapshot, not peak memory. No automatic energy measurements. Trials stop on backgrounding; thermal state is recorded. Codec viewport is 1179×1179 physical pixels.

Device: arm64 · Apple iOS simulator GPU

Simulator: **True** · Build: Release · Protocol: smoke / 1 repeat · Complete: True

> Simulator data verifies behavior only. It does not establish iPhone GPU, CPU, or energy performance.

## Encoding

All sizes include the 16-byte file header. Timing excludes disk and network I/O.

| Dataset | Dots | Format | Raw bytes | LZFSE bytes | Open p50 (ms) | Open p95 (ms) | Max position error (px) | Max radius error (px) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| orbital | 10,000 | Float32 interleaved | 120,016 | 109,207 | 0.200 | 0.207 | 0.00000 | 0.00000 |
| orbital | 10,000 | Quantized interleaved | 50,016 | 49,818 | 0.104 | 0.109 | 0.01272 | 0.00925 |
| orbital | 10,000 | Quantized planar | 50,016 | 48,463 | 0.258 | 0.262 | 0.01272 | 0.00925 |
| orbital | 10,000 | Quantized planar + delta | 50,016 | 49,513 | 0.255 | 0.259 | 0.01272 | 0.00925 |
| uniform | 10,000 | Float32 interleaved | 120,016 | 110,560 | 0.215 | 0.218 | 0.00000 | 0.00000 |
| uniform | 10,000 | Quantized interleaved | 50,016 | 50,686 | 0.122 | 0.123 | 0.01257 | 0.00925 |
| uniform | 10,000 | Quantized planar | 50,016 | 48,776 | 0.252 | 0.259 | 0.01257 | 0.00925 |
| uniform | 10,000 | Quantized planar + delta | 50,016 | 49,592 | 0.258 | 0.265 | 0.01257 | 0.00925 |
| orbital | 50,000 | Float32 interleaved | 600,016 | 545,961 | 1.046 | 1.088 | 0.00000 | 0.00000 |
| orbital | 50,000 | Quantized interleaved | 250,016 | 248,411 | 0.466 | 0.467 | 0.01272 | 0.00925 |
| orbital | 50,000 | Quantized planar | 250,016 | 241,533 | 1.206 | 1.362 | 0.01272 | 0.00925 |
| orbital | 50,000 | Quantized planar + delta | 250,016 | 246,895 | 1.152 | 1.249 | 0.01272 | 0.00925 |
| uniform | 50,000 | Float32 interleaved | 600,016 | 552,038 | 1.020 | 1.084 | 0.00000 | 0.00000 |
| uniform | 50,000 | Quantized interleaved | 250,016 | 253,006 | 0.466 | 0.471 | 0.01267 | 0.00925 |
| uniform | 50,000 | Quantized planar | 250,016 | 243,407 | 1.220 | 1.249 | 0.01267 | 0.00925 |
| uniform | 50,000 | Quantized planar + delta | 250,016 | 247,255 | 1.159 | 1.198 | 0.01267 | 0.00925 |
| orbital | 100,000 | Float32 interleaved | 1,200,016 | 1,091,786 | 1.861 | 1.946 | 0.00000 | 0.00000 |
| orbital | 100,000 | Quantized interleaved | 500,016 | 496,680 | 0.899 | 0.905 | 0.01272 | 0.00925 |
| orbital | 100,000 | Quantized planar | 500,016 | 481,789 | 2.378 | 2.467 | 0.01272 | 0.00925 |
| orbital | 100,000 | Quantized planar + delta | 500,016 | 492,947 | 2.450 | 2.477 | 0.01272 | 0.00925 |
| uniform | 100,000 | Float32 interleaved | 1,200,016 | 1,102,774 | 1.901 | 1.951 | 0.00000 | 0.00000 |
| uniform | 100,000 | Quantized interleaved | 500,016 | 505,692 | 0.911 | 0.936 | 0.01272 | 0.00925 |
| uniform | 100,000 | Quantized planar | 500,016 | 485,626 | 2.335 | 2.364 | 0.01272 | 0.00925 |
| uniform | 100,000 | Quantized planar + delta | 500,016 | 493,637 | 2.403 | 2.447 | 0.01272 | 0.00925 |

## Rendered trials

Submission is elapsed wall time, including waits. Missed refreshes are callback-spacing estimates. A zero idle-frame count means the renderer submitted no new frames during that phase.

| Dots | Mode | Repeat | Submit p95 (ms) | GPU p95 (ms) | Interval p95 (ms) | Est. missed | Idle frames | Idle steps | Settled | Thermal start/end |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| 10,000 | continuous | 1 | 3.463 | 0.470 | 16.897 | 0 | 185 | 370 | True | 0/0 |
| 100,000 | activeSoA | 1 | 10.351 | 0.386 | 16.705 | 1 | 0 | 0 | True | 0/0 |
| 50,000 | activeAoS | 1 | 7.541 | 0.403 | 16.776 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | activeAoS | 1 | 1.867 | 0.350 | 16.775 | 1 | 0 | 0 | True | 0/0 |
| 50,000 | sleep | 1 | 6.701 | 0.424 | 16.696 | 0 | 0 | 0 | True | 0/0 |
| 100,000 | activeAoS | 1 | 8.192 | 0.547 | 17.090 | 1 | 0 | 0 | True | 0/0 |
| 10,000 | sleep | 1 | 3.048 | 0.379 | 16.956 | 0 | 0 | 0 | True | 0/0 |
| 50,000 | activeSoA | 1 | 6.263 | 0.444 | 16.704 | 1 | 0 | 0 | True | 0/0 |
| 100,000 | sleep | 1 | 14.125 | 0.322 | 26.247 | 6 | 0 | 0 | True | 0/0 |
| 50,000 | continuous | 1 | 9.013 | 0.411 | 16.692 | 0 | 185 | 369 | True | 0/0 |
| 10,000 | activeSoA | 1 | 2.724 | 0.461 | 16.832 | 1 | 0 | 0 | True | 0/0 |
| 100,000 | continuous | 1 | 19.019 | 0.337 | 33.350 | 20 | 178 | 366 | True | 0/0 |
