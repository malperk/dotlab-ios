import DotLabCore
import SwiftUI

private let mint = Color(red: 0.49, green: 0.94, blue: 0.77)
private let labBackground = Color(red: 0.022, green: 0.034, blue: 0.049)

struct LabView: View {
    @ObservedObject var model: LabModel
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Picker("Workspace", selection: $selectedTab) {
                    Text("Playground").tag(0)
                    Text("Data formats").tag(1)
                    Text("Benchmark").tag(2)
                }
                .pickerStyle(.segmented)
                if model.isRunning {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.status).font(.system(size: 11, design: .monospaced))
                        ProgressView(value: model.progress).tint(mint)
                    }
                }
                // Keep the renderer mounted in every tab, including automated runs.
                playground
                if selectedTab == 1 { dataPanel }
                if selectedTab == 2 { benchmarkPanel }
                footer
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(labBackground)
        .tint(mint)
        .alert("DotLab", isPresented: Binding(get: { model.errorMessage != nil },
                                               set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "circle.hexagongrid.fill").foregroundStyle(mint)
                    Text("DOTLAB").tracking(3)
                }.font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
                Text("EXPERIMENT 001")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }
            Text("Less work.\nSame wonder.")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .tracking(-1.8)
                .fixedSize(horizontal: false, vertical: true)
            Text("A particle field. Four ways to run it. Measurable tradeoffs.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var playground: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(model.sleeping ? "RESTING" : "IN MOTION",
                      systemImage: model.sleeping ? "moon.fill" : "waveform.path")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(model.sleeping ? mint : .orange)
                Spacer()
                Text("\(model.count.formatted()) DOTS")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            if let renderer = model.renderer {
                GeometryReader { geometry in
                    ParticleCanvas(renderer: renderer)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !model.isRunning else { return }
                                renderer.touch = SIMD2(Float(value.location.x / geometry.size.width),
                                                       Float(value.location.y / geometry.size.height))
                            }
                            .onEnded { _ in if !model.isRunning { renderer.touch = nil } })
                        .accessibilityLabel("Interactive orbital particle field")
                        .accessibilityHint("Drag to disturb nearby dots. They return to their resting positions.")
                }
                .aspectRatio(1, contentMode: .fit)
            } else {
                ContentUnavailableView("Metal unavailable", systemImage: "exclamationmark.triangle")
            }
            HStack(spacing: 0) {
                metric("ACTIVE", value: model.activeCount.formatted())
                metric("SUBMIT", value: String(format: "%.2f ms", model.submissionMS))
                metric("GPU", value: String(format: "%.2f ms", model.gpuMS))
            }
            Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
            Picker("Dot count", selection: $model.count) {
                Text("10K").tag(10_000); Text("50K").tag(50_000); Text("100K").tag(100_000)
            }
            .pickerStyle(.segmented)
            .disabled(model.isRunning)
            .onChange(of: model.count) { _, _ in model.reset() }
            HStack {
                Menu {
                    ForEach(SimulationMode.allCases, id: \.self) { mode in
                        Button(mode.label) { model.mode = mode; model.reset() }
                    }
                } label: {
                    HStack {
                        Text(model.mode.label).font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }
                }.disabled(model.isRunning)
                Spacer()
                Button { model.replay() } label: {
                    Label("Replay", systemImage: "play.fill").font(.system(size: 12, weight: .medium))
                }.disabled(model.isRunning)
            }
        }
        .padding(16)
        .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.09), lineWidth: 1))
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .medium, design: .monospaced)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dataPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The shape of the bytes").font(.title3.weight(.semibold))
            Text("Every format opens into the same Float32 runtime data. Compression and simulation are measured separately.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Measure \(model.count.formatted()) dots") { model.analyzeCodec() }
                .buttonStyle(.borderedProminent).foregroundStyle(labBackground)
                .disabled(model.isRunning)
            ForEach(model.codecRows.indices, id: \.self) { index in
                let row = model.codecRows[index]
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.format.label).font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(row.compressedBytes), countStyle: .file))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(mint)
                    }
                    Text(String(format: "Open p50 %.2f ms · position error %.4f px · radius error %.4f px",
                                row.totalP50MS, row.maxPositionErrorPixels, row.maxRadiusErrorPixels))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            Text("Error viewport: 1179 × 1179 physical pixels. LZFSE in all variants.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var benchmarkPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Make the comparison fair").font(.title3.weight(.semibold))
            Text("Three dot counts × four modes. Identical scripted interaction, seeded trial order, raw samples, and thermal state in every export.")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                Button("Smoke test") { model.startSuite(quick: true) }
                    .buttonStyle(.bordered).disabled(model.isRunning)
                Button("Full suite · 5 repeats") { model.startSuite(quick: false) }
                    .buttonStyle(.borderedProminent).foregroundStyle(labBackground).disabled(model.isRunning)
            }.font(.system(size: 11, weight: .medium))
            Text("Smoke: about 2 minutes. Full: about 55 minutes. Keep the app in the foreground; leaving it stops the suite and saves partial results.")
                .font(.caption).foregroundStyle(.secondary)
            if model.isRunning {
                ProgressView(value: model.progress).tint(mint)
                Button("Stop and save") { model.cancel() }.font(.footnote)
            }
            if let url = model.exportURL {
                ShareLink(item: url) { Label("Export JSON results", systemImage: "square.and.arrow.up") }
                    .font(.footnote.weight(.medium))
            }
            Text("Submission time includes CPU work and waits. GPU time is command execution. Neither is battery usage. Use Instruments on a real device for CPU utilization, peak memory, display timing, and power.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.status).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Text("BUILT TO BE MEASURED").tracking(1.5)
                Spacer()
                Text("ALPER KARATAS")
            }.font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary.opacity(0.65))
        }
    }
}
