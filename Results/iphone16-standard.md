# DotLab benchmark results

Recorded: 2026-10-26T12:27:35Z

Platform: iOS · Version 26.6.1 (Build 23G83)

Release build required for interpretation. Metal instanced quads; CPU fixed-step physics. Submission times are elapsed wall time including drawable/semaphore waits, not process CPU utilization. GPU execution is command-buffer time, not display latency. Missed refreshes are estimates from callback spacing. RSS is a post-trial snapshot, not peak memory. No automatic energy measurements. Trials stop on backgrounding; thermal state is recorded. Codec viewport is 1179×1179 physical pixels.

Device: iPhone17,3 · Apple A18 GPU

Simulator: **False** · Build: Release · Protocol: standard / 5 repeats · Complete: True

## Encoding

All sizes include the 16-byte file header. Timing excludes disk and network I/O.

| Dataset | Dots | Format | Raw bytes | LZFSE bytes | Open p50 (ms) | Open p95 (ms) | Max position error (px) | Max radius error (px) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| orbital | 10,000 | Float32 interleaved | 120,016 | 109,207 | 0.385 | 0.463 | 0.00000 | 0.00000 |
| orbital | 10,000 | Quantized interleaved | 50,016 | 49,818 | 0.176 | 0.245 | 0.01272 | 0.00925 |
| orbital | 10,000 | Quantized planar | 50,016 | 48,463 | 0.532 | 0.552 | 0.01272 | 0.00925 |
| orbital | 10,000 | Quantized planar + delta | 50,016 | 49,513 | 0.423 | 0.426 | 0.01272 | 0.00925 |
| uniform | 10,000 | Float32 interleaved | 120,016 | 110,560 | 0.245 | 0.296 | 0.00000 | 0.00000 |
| uniform | 10,000 | Quantized interleaved | 50,016 | 50,686 | 0.114 | 0.115 | 0.01257 | 0.00925 |
| uniform | 10,000 | Quantized planar | 50,016 | 48,776 | 0.307 | 0.317 | 0.01257 | 0.00925 |
| uniform | 10,000 | Quantized planar + delta | 50,016 | 49,592 | 0.282 | 0.286 | 0.01257 | 0.00925 |
| orbital | 50,000 | Float32 interleaved | 600,016 | 545,961 | 0.793 | 0.874 | 0.00000 | 0.00000 |
| orbital | 50,000 | Quantized interleaved | 250,016 | 248,411 | 0.329 | 0.334 | 0.01272 | 0.00925 |
| orbital | 50,000 | Quantized planar | 250,016 | 241,533 | 1.003 | 1.009 | 0.01272 | 0.00925 |
| orbital | 50,000 | Quantized planar + delta | 250,016 | 246,895 | 1.002 | 1.007 | 0.01272 | 0.00925 |
| uniform | 50,000 | Float32 interleaved | 600,016 | 552,038 | 0.714 | 0.722 | 0.00000 | 0.00000 |
| uniform | 50,000 | Quantized interleaved | 250,016 | 253,006 | 0.328 | 0.331 | 0.01267 | 0.00925 |
| uniform | 50,000 | Quantized planar | 250,016 | 243,407 | 1.002 | 1.008 | 0.01267 | 0.00925 |
| uniform | 50,000 | Quantized planar + delta | 250,016 | 247,255 | 1.003 | 1.006 | 0.01267 | 0.00925 |
| orbital | 100,000 | Float32 interleaved | 1,200,016 | 1,091,786 | 1.427 | 1.436 | 0.00000 | 0.00000 |
| orbital | 100,000 | Quantized interleaved | 500,016 | 496,680 | 0.654 | 0.658 | 0.01272 | 0.00925 |
| orbital | 100,000 | Quantized planar | 500,016 | 481,789 | 1.998 | 2.006 | 0.01272 | 0.00925 |
| orbital | 100,000 | Quantized planar + delta | 500,016 | 492,947 | 2.001 | 2.007 | 0.01272 | 0.00925 |
| uniform | 100,000 | Float32 interleaved | 1,200,016 | 1,102,774 | 1.425 | 1.439 | 0.00000 | 0.00000 |
| uniform | 100,000 | Quantized interleaved | 500,016 | 505,692 | 0.658 | 0.683 | 0.01272 | 0.00925 |
| uniform | 100,000 | Quantized planar | 500,016 | 485,626 | 1.999 | 2.032 | 0.01272 | 0.00925 |
| uniform | 100,000 | Quantized planar + delta | 500,016 | 493,637 | 2.001 | 2.013 | 0.01272 | 0.00925 |

## Rendered trials

Submission is elapsed wall time, including waits. Missed refreshes are callback-spacing estimates. A zero idle-frame count means the renderer submitted no new frames during that phase.

| Dots | Mode | Repeat | Submit p95 (ms) | GPU p95 (ms) | Interval p95 (ms) | Est. missed | Idle frames | Idle steps | Settled | Thermal start/end |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| 10,000 | activeAoS | 4 | 5.723 | 0.572 | 16.664 | 1 | 0 | 0 | True | 0/0 |
| 50,000 | activeAoS | 1 | 9.619 | 2.718 | 16.666 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | continuous | 1 | 18.216 | 0.583 | 19.055 | 0 | 1808 | 3611 | True | 0/0 |
| 100,000 | activeAoS | 2 | 12.660 | 5.196 | 16.676 | 0 | 0 | 0 | True | 0/0 |
| 50,000 | sleep | 4 | 9.899 | 2.708 | 16.677 | 3 | 0 | 0 | True | 0/0 |
| 50,000 | activeAoS | 3 | 9.659 | 2.727 | 16.666 | 0 | 0 | 0 | True | 0/0 |
| 50,000 | activeSoA | 4 | 12.901 | 2.720 | 16.679 | 1 | 0 | 0 | True | 0/0 |
| 10,000 | sleep | 1 | 7.898 | 0.572 | 16.669 | 0 | 0 | 0 | True | 0/0 |
| 100,000 | activeAoS | 4 | 12.984 | 5.216 | 16.724 | 1 | 0 | 0 | True | 0/0 |
| 50,000 | sleep | 3 | 12.870 | 2.713 | 16.681 | 1 | 0 | 0 | True | 0/0 |
| 100,000 | sleep | 2 | 17.006 | 5.167 | 17.876 | 1 | 0 | 0 | True | 0/0 |
| 50,000 | activeSoA | 1 | 13.189 | 2.741 | 16.670 | 0 | 0 | 0 | True | 0/0 |
| 100,000 | sleep | 4 | 10.355 | 5.165 | 16.683 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | continuous | 5 | 7.791 | 0.582 | 16.661 | 0 | 1810 | 3614 | True | 0/0 |
| 10,000 | sleep | 3 | 7.870 | 0.572 | 16.664 | 0 | 0 | 0 | True | 0/0 |
| 100,000 | activeAoS | 3 | 12.904 | 5.205 | 16.689 | 1 | 0 | 0 | True | 0/0 |
| 100,000 | continuous | 1 | 10.348 | 5.168 | 16.680 | 0 | 1808 | 3611 | True | 0/0 |
| 50,000 | continuous | 5 | 12.769 | 2.712 | 16.675 | 0 | 1803 | 3600 | True | 0/0 |
| 100,000 | continuous | 3 | 10.473 | 5.183 | 16.675 | 0 | 1816 | 3627 | True | 0/0 |
| 50,000 | activeAoS | 2 | 9.658 | 2.721 | 16.667 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | activeAoS | 2 | 5.657 | 0.573 | 16.664 | 1 | 0 | 0 | True | 0/0 |
| 100,000 | sleep | 5 | 17.133 | 5.202 | 18.199 | 2 | 0 | 0 | True | 0/0 |
| 100,000 | activeSoA | 4 | 13.732 | 5.158 | 16.672 | 3 | 0 | 0 | True | 0/0 |
| 50,000 | activeSoA | 3 | 12.954 | 2.716 | 16.677 | 0 | 0 | 0 | True | 0/0 |
| 50,000 | activeAoS | 5 | 9.797 | 2.733 | 16.665 | 0 | 0 | 0 | True | 0/0 |
| 50,000 | sleep | 5 | 12.454 | 2.718 | 16.672 | 1 | 0 | 0 | True | 0/0 |
| 100,000 | activeSoA | 3 | 10.413 | 5.167 | 16.673 | 2 | 0 | 0 | True | 0/0 |
| 10,000 | continuous | 3 | 7.917 | 0.580 | 16.669 | 1 | 1807 | 3608 | True | 0/0 |
| 50,000 | sleep | 2 | 12.811 | 2.711 | 16.674 | 1 | 0 | 0 | True | 0/0 |
| 50,000 | sleep | 1 | 13.430 | 2.718 | 16.908 | 3 | 0 | 0 | True | 0/0 |
| 50,000 | continuous | 4 | 12.774 | 2.711 | 16.669 | 0 | 1809 | 3612 | True | 0/0 |
| 50,000 | activeAoS | 4 | 18.378 | 2.814 | 19.047 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | activeSoA | 2 | 7.890 | 0.571 | 16.674 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | activeAoS | 5 | 5.678 | 0.572 | 16.665 | 0 | 0 | 0 | True | 0/0 |
| 100,000 | activeSoA | 5 | 15.956 | 5.207 | 16.683 | 3 | 0 | 0 | True | 0/0 |
| 100,000 | continuous | 5 | 10.422 | 5.175 | 16.682 | 0 | 1809 | 3613 | True | 0/0 |
| 100,000 | activeSoA | 2 | 19.286 | 5.184 | 19.360 | 3 | 0 | 0 | True | 0/0 |
| 50,000 | continuous | 2 | 12.776 | 2.775 | 16.680 | 0 | 1804 | 3602 | True | 0/0 |
| 10,000 | activeAoS | 1 | 5.703 | 0.572 | 16.668 | 0 | 0 | 0 | True | 0/0 |
| 100,000 | activeAoS | 5 | 15.353 | 5.338 | 16.754 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | activeSoA | 5 | 17.930 | 0.572 | 18.377 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | activeSoA | 3 | 7.664 | 0.573 | 16.676 | 0 | 0 | 0 | True | 0/0 |
| 100,000 | continuous | 4 | 17.199 | 5.169 | 18.024 | 0 | 1811 | 3617 | True | 0/0 |
| 100,000 | activeAoS | 1 | 12.907 | 5.207 | 16.686 | 2 | 0 | 0 | True | 0/0 |
| 50,000 | activeSoA | 2 | 12.868 | 2.713 | 16.677 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | sleep | 5 | 7.737 | 0.572 | 16.670 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | continuous | 4 | 7.857 | 0.578 | 16.667 | 0 | 1826 | 3646 | True | 0/0 |
| 100,000 | activeSoA | 1 | 10.693 | 5.184 | 16.676 | 1 | 0 | 0 | True | 0/0 |
| 10,000 | continuous | 2 | 17.640 | 0.578 | 18.514 | 0 | 1805 | 3604 | True | 0/0 |
| 100,000 | sleep | 3 | 10.466 | 5.174 | 16.685 | 1 | 0 | 0 | True | 0/0 |
| 10,000 | sleep | 2 | 17.365 | 0.571 | 18.361 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | activeAoS | 3 | 5.627 | 0.572 | 16.665 | 0 | 0 | 0 | True | 0/0 |
| 50,000 | continuous | 1 | 12.849 | 2.717 | 16.675 | 0 | 1808 | 3611 | True | 0/0 |
| 50,000 | activeSoA | 5 | 14.057 | 2.727 | 16.723 | 1 | 0 | 0 | True | 0/0 |
| 100,000 | sleep | 1 | 10.369 | 5.170 | 16.677 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | activeSoA | 4 | 17.709 | 0.572 | 18.362 | 0 | 0 | 0 | True | 0/0 |
| 10,000 | sleep | 4 | 7.825 | 0.572 | 16.664 | 0 | 0 | 0 | True | 0/0 |
| 50,000 | continuous | 3 | 12.871 | 2.724 | 16.673 | 0 | 1807 | 3608 | True | 0/0 |
| 10,000 | activeSoA | 1 | 17.372 | 0.572 | 18.113 | 1 | 0 | 0 | True | 0/0 |
| 100,000 | continuous | 2 | 10.443 | 5.189 | 16.674 | 0 | 1805 | 3605 | True | 0/0 |
