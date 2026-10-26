# DotLab benchmark results

Recorded: 2026-10-26T12:43:54Z

Platform: macOS / CPU only · Version 27.0.1 (Build 26A434)

Release recommended. No GPU, display, iPhone energy, or app-startup measurements. Decode samples exclude disk I/O and include format validation. Host may be shared with other processes.

## Encoding

All sizes include the 16-byte file header. Timing excludes disk and network I/O.

| Dataset | Dots | Format | Raw bytes | LZFSE bytes | Open p50 (ms) | Open p95 (ms) | Max position error (px) | Max radius error (px) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| orbital | 10,000 | Float32 interleaved | 120,016 | 109,207 | 0.168 | 0.183 | 0.00000 | 0.00000 |
| orbital | 10,000 | Quantized interleaved | 50,016 | 49,818 | 0.079 | 0.081 | 0.01272 | 0.00925 |
| orbital | 10,000 | Quantized planar | 50,016 | 48,463 | 0.249 | 0.257 | 0.01272 | 0.00925 |
| orbital | 10,000 | Quantized planar + delta | 50,016 | 49,513 | 0.249 | 0.292 | 0.01272 | 0.00925 |
| uniform | 10,000 | Float32 interleaved | 120,016 | 110,560 | 0.168 | 0.172 | 0.00000 | 0.00000 |
| uniform | 10,000 | Quantized interleaved | 50,016 | 50,686 | 0.079 | 0.084 | 0.01257 | 0.00925 |
| uniform | 10,000 | Quantized planar | 50,016 | 48,776 | 0.248 | 0.252 | 0.01257 | 0.00925 |
| uniform | 10,000 | Quantized planar + delta | 50,016 | 49,592 | 0.249 | 0.255 | 0.01257 | 0.00925 |
| orbital | 50,000 | Float32 interleaved | 600,016 | 545,961 | 0.810 | 0.889 | 0.00000 | 0.00000 |
| orbital | 50,000 | Quantized interleaved | 250,016 | 248,411 | 0.374 | 0.403 | 0.01272 | 0.00925 |
| orbital | 50,000 | Quantized planar | 250,016 | 241,533 | 1.231 | 1.491 | 0.01272 | 0.00925 |
| orbital | 50,000 | Quantized planar + delta | 250,016 | 246,895 | 1.226 | 1.332 | 0.01272 | 0.00925 |
| uniform | 50,000 | Float32 interleaved | 600,016 | 552,038 | 0.809 | 0.823 | 0.00000 | 0.00000 |
| uniform | 50,000 | Quantized interleaved | 250,016 | 253,006 | 0.375 | 0.397 | 0.01267 | 0.00925 |
| uniform | 50,000 | Quantized planar | 250,016 | 243,407 | 1.222 | 1.243 | 0.01267 | 0.00925 |
| uniform | 50,000 | Quantized planar + delta | 250,016 | 247,255 | 1.223 | 1.258 | 0.01267 | 0.00925 |
| orbital | 100,000 | Float32 interleaved | 1,200,016 | 1,091,786 | 1.616 | 1.651 | 0.00000 | 0.00000 |
| orbital | 100,000 | Quantized interleaved | 500,016 | 496,680 | 0.745 | 0.748 | 0.01272 | 0.00925 |
| orbital | 100,000 | Quantized planar | 500,016 | 481,789 | 2.443 | 2.490 | 0.01272 | 0.00925 |
| orbital | 100,000 | Quantized planar + delta | 500,016 | 492,947 | 2.444 | 2.476 | 0.01272 | 0.00925 |
| uniform | 100,000 | Float32 interleaved | 1,200,016 | 1,102,774 | 1.614 | 1.636 | 0.00000 | 0.00000 |
| uniform | 100,000 | Quantized interleaved | 500,016 | 505,692 | 0.745 | 0.756 | 0.01272 | 0.00925 |
| uniform | 100,000 | Quantized planar | 500,016 | 485,626 | 2.443 | 2.562 | 0.01272 | 0.00925 |
| uniform | 100,000 | Quantized planar + delta | 500,016 | 493,637 | 2.461 | 2.541 | 0.01272 | 0.00925 |

## CPU simulation microbenchmark

Median of trial percentiles. Each timed sample is one 1/120 s physics step during interaction. These are not rendered frame times. Total work includes settling; hit tests cover interaction.

| Dots | Mode | Repeats | Update p50 (ms) | Update p95 (ms) | Updated / trial | Hit tests / trial | All settled |
|---:|---|---:|---:|---:|---:|---:|---|
| 10,000 | activeAoS | 5 | 0.0885 | 0.1070 | 5,889,953 | 3,595,776 | True |
| 10,000 | activeSoA | 5 | 0.2334 | 0.2812 | 5,889,953 | 3,595,776 | True |
| 10,000 | continuous | 5 | 0.2913 | 0.3127 | 13,410,000 | 12,000,000 | True |
| 10,000 | sleep | 5 | 0.2920 | 0.3205 | 13,410,000 | 12,000,000 | True |
| 50,000 | activeAoS | 5 | 0.4382 | 0.5327 | 29,388,065 | 17,990,800 | True |
| 50,000 | activeSoA | 5 | 1.1687 | 1.3998 | 29,388,065 | 17,990,800 | True |
| 50,000 | continuous | 5 | 1.4506 | 1.5637 | 67,050,000 | 60,000,000 | True |
| 50,000 | sleep | 5 | 1.4635 | 1.5734 | 67,050,000 | 60,000,000 | True |
| 100,000 | activeAoS | 5 | 0.8982 | 1.1053 | 58,732,185 | 35,975,178 | True |
| 100,000 | activeSoA | 5 | 2.3136 | 2.8175 | 58,732,185 | 35,975,178 | True |
| 100,000 | continuous | 5 | 2.9118 | 3.1305 | 134,100,000 | 120,000,000 | True |
| 100,000 | sleep | 5 | 2.9186 | 3.1474 | 134,100,000 | 120,000,000 | True |
