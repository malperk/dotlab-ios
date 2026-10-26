# Measurement protocol

## Hypotheses

1. Quantization reduces the raw payload while remaining below a declared image-space error tolerance.
2. Grouping homogeneous fields may improve compression. The effect depends on source distribution and compressor.
3. Stopping the renderer after settling eliminates its periodic simulation/render submissions during idle.
4. Updating active particles reduces physics and hit-test work under local interaction.
5. SoA may help or hurt this workload. Both implementations must be measured with identical math and active indices.

## Controls

- Generator seed: `103802`; trial shuffle seed: `82`.
- Counts: 10,000; 50,000; 100,000.
- Encoding controls: original order, all four formats, LZFSE, identical `[Dot]` decoded format.
- Datasets: orbital illustration and uniform random control.
- Coordinate bounds: `[0,1]`; radius bounds: `[0,0.004]` of view width.
- Error viewport: 1179×1179 physical pixels. Position error is Euclidean, not per-axis.
- Renderer: one instanced triangle draw, six vertices per dot, same blending and shader.
- CPU physics: semi-implicit Euler, `dt = 1/120`, spring 60, damping 12.
- Target rendering frequency: 60 FPS, including ProMotion devices.
- Interaction: deterministic analytic path, local repulsion in rest-coordinate space.
- Grid: 16×16 home-coordinate bins; only active modes use the grid.
- Settle threshold: squared displacement below `1e-9` and squared velocity below `1e-7`; final state snaps exactly to home.
- In-flight rendering: three caller-owned shared Metal buffers; semaphore prevents writing a buffer still in use by the GPU.
- UI stats refresh: 2 Hz in all modes. The app is a measurement tool, so optimized idle means zero *renderer* work, not an entirely inactive process.

## Standard iPhone run

Use a Release build on a physical device. Record the commit being measured, OS, GPU, thermal state, battery/charging condition, brightness, Low Power Mode, and refresh-rate accessibility settings alongside the raw export. Do not compare absolute power-impact scores across different iPhone models.

Minimize unrelated workloads and notifications, keep brightness fixed, and start with nominal thermal state. Trial order is shuffled deterministically rather than grouping all baselines together. Thermal start/end states are included so a reviewer can detect problematic runs. The app does not change brightness, Low Power Mode, or system thermal settings.

Each of 60 trials has:

1. Construct the source dataset and simulation; create the common render buffers.
2. Submit the initial image; wait 1 second for warmup.
3. Initial idle: 10 seconds.
4. Scripted interaction: 10 seconds.
5. Settle: poll every 50 ms, maximum 10 seconds.
6. Final idle: 30 seconds.
7. Pause, drain completion callbacks briefly, and atomically checkpoint the export.

The source generator and physics reset occur outside the interaction/idle intervals. Reset-to-first-submission time is recorded separately. The timing includes renderer initialization/buffer creation after reset begins, but excludes source generation and file decoding.

The script is evaluated at elapsed interaction wall time in each rendered frame. Physics uses an accumulator with fixed 1/120-second steps. Frame gaps above 1/15 second are clamped, and the discarded simulation duration is recorded. Consequently, heavily stalled rendered runs may process different step counts. The headless CPU benchmark supplies the same touch point for exactly 1200 steps and is the deterministic work/trajectory control.

The app stops when leaving the foreground. Partial exports have `completed: false` and must not be treated as complete comparisons. A serious/critical thermal interval invalidates a clean performance claim; rerun after cooling rather than silently dropping inconvenient rows.

## Smoke protocol

One repeat per count/mode, 1 second initial idle, 2 seconds interaction, up to 10 seconds settling, and 3 seconds final idle. This checks lifecycle, GPU errors, frame production, settlement, export, and idle behavior. It is not a substitute for a standard timing or energy experiment.

## Encoding samples

The standard benchmark records 20 samples per format/dataset/count after one untimed decompression and decode. The smoke version records 3. Input construction, encoding, and compression happen outside the open-time measurement.

`decompressP50MS` and `decodeP50MS` describe the separate stages; `totalP50MS` and `totalP95MS` describe the total sample, not a sum of stage percentiles. The decoder validates the header, exact output size, bounds, and finite floats. These safety checks are included in decode time.

Every format is measured sequentially. Encoding timing is useful for build pipelines but is intentionally not part of the client-open metric. Codec row order is fixed and may have cache/thermal order effects; repeat the experiment with another order if small timing differences drive a decision.

## Instruments follow-up

Use Product → Profile. DotLab emits `DotLab frame`, `benchmark phase`, and `settling` signposts under `com.alperkaratas.dotlab`.

- **Time Profiler / CPU tools:** distinguish real CPU utilization from wall-clock submission timing, and attribute time to candidate lookup, integration, upload, or command encoding.
- **Metal System Trace / Game Performance:** inspect GPU execution and actual display deadlines. A p95 GPU duration below 16.67 ms alone does not prove 60 FPS.
- **Allocations / VM tracking:** measure per-format decompression/decoder peaks separately from renderer buffers and report both persistent and temporary allocations. The JSON's resident-memory snapshot is not a substitute.
- **Power Profiler on iOS 26+:** compare long fixed-duration R0 idle and optimized idle recordings on the same phone with fixed brightness and battery conditions. Collect multiple traces per mode. Charging can make overall-system power unavailable/zero; use the supported untethered or wireless workflow for battery claims. Keep profiler-enabled runs separate from the primary timing run.

Do not infer a battery percentage improvement from CPU time, GPU time, or fewer frame submissions. Save raw traces locally; they can contain device/process information beyond this project.

## Acceptance and decisions

| Check | Criterion |
|---|---|
| Data correctness | Float32 lossless; quantized variants agree exactly |
| Visual geometry | Maximum position and radius error each ≤0.25 physical pixels at declared viewport |
| Physics correctness | Identical positions across all modes for fixed-step scripted input |
| Settlement | All trials settle within 10 seconds |
| Idle scheduling | R1/R2/R3: zero submitted frames and zero physics steps in final idle |
| Baseline control | R0 keeps producing idle frames |
| Main performance target | Evaluate 50K at a 60 FPS target on the physical device, using interval and trace evidence |
| Stress case | Report 100K even if it misses the target |
| Data format choice | Weigh bytes against total open time and peak memory |
| Runtime layout choice | Keep the faster measured implementation for this workload |
| GPU compute | Add only if profiling shows CPU physics prevents meeting the target |

`Scripts/validate-results.py` checks the recorded correctness and idle-work invariants. It deliberately does not automatically claim energy savings, perceptual equivalence, or compositor-level frame-rate success.
