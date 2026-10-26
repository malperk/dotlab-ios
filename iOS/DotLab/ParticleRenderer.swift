import DotLabCore
import MetalKit
import SwiftUI
import os

enum RunPhase: String, Codable, CaseIterable { case warmup, preIdle, interaction, settling, idle }

struct PhaseSamples: Codable {
    var frames = 0
    var simulationSteps = 0
    var updated = 0
    var hitTests = 0
    var cpuMS: [Double] = []
    var simulationMS: [Double] = []
    var gpuMS: [Double] = []
    var intervalsMS: [Double] = []
    var estimatedMissedRefreshes = 0
    var droppedSimulationSeconds = 0.0
}

@MainActor
final class ParticleRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let inFlight = DispatchSemaphore(value: 3)
    private var buffers: [MTLBuffer] = []
    private var bufferIndex = 0
    private(set) var simulation: Simulation
    private(set) var mode: SimulationMode
    weak var view: MTKView?
    var touch: SIMD2<Float>? { didSet { if touch != nil { wake() } } }
    var scriptStart: CFTimeInterval? { didSet { if scriptStart != nil { wake() } } }
    var phase: RunPhase = .warmup
    var samples: [RunPhase: PhaseSamples] = [:]
    var generation = UUID()
    private var lastTime: CFTimeInterval?
    private var lastPhase: RunPhase?
    private var accumulator: Double = 0
    private let logger = OSLog(subsystem: "com.alperkaratas.dotlab", category: .pointsOfInterest)
    private(set) var totalFrames = 0
    private(set) var lastError: String?
    private(set) var lastCPU = 0.0
    private(set) var lastGPU = 0.0
    private(set) var firstFrameMS = 0.0
    private var loadStart = CACurrentMediaTime()

    init(dots: [Dot], mode: SimulationMode) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "dotVertex"),
              let fragment = library.makeFunction(name: "dotFragment") else {
            throw RendererError.unavailable
        }
        self.device = device
        self.queue = queue
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        simulation = Simulation(dots: dots, mode: mode)
        self.mode = mode
        super.init()
        try makeBuffers(count: dots.count)
    }

    func configure(_ view: MTKView) {
        self.view = view
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.022, green: 0.034, blue: 0.049, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        // The initial view has zero bounds. Let the first display tick render
        // after layout, then draw(in:) pauses an idle optimized mode.
        view.isPaused = false
        view.delegate = self
        view.draw()
    }

    func reset(dots: [Dot], mode: SimulationMode) throws {
        // Drain old submissions before replacing buffers; callbacks carry a generation.
        for _ in 0..<3 { inFlight.wait() }
        for _ in 0..<3 { inFlight.signal() }
        loadStart = CACurrentMediaTime()
        simulation = Simulation(dots: dots, mode: mode)
        self.mode = mode
        try makeBuffers(count: dots.count)
        touch = nil; scriptStart = nil
        lastTime = nil; lastPhase = nil; accumulator = 0
        samples = [:]; generation = UUID(); totalFrames = 0; firstFrameMS = 0
        lastError = nil
        view?.isPaused = false
    }

    private func makeBuffers(count: Int) throws {
        buffers = try (0..<3).map { _ in
            guard let buffer = device.makeBuffer(length: max(16, count * MemoryLayout<SIMD4<Float>>.stride),
                                                 options: .storageModeShared) else {
                throw RendererError.allocationFailed
            }
            return buffer
        }
        bufferIndex = 0
    }

    func wake() {
        if view?.isPaused == true { lastTime = nil }
        view?.isPaused = false
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Redraw the static image after resize; do not restart a perpetual loop.
        wake()
    }

    func draw(in view: MTKView) {
        let start = CACurrentMediaTime()
        guard let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer() else { return }
        inFlight.wait()
        os_signpost(.begin, log: logger, name: "DotLab frame")
        let framePhase = phase
        var row = samples.removeValue(forKey: framePhase) ?? PhaseSamples()
        if let previous = lastTime, lastPhase == framePhase {
            let interval = start - previous
            row.intervalsMS.append(interval * 1000)
            row.estimatedMissedRefreshes += max(0, Int((interval * 60).rounded()) - 1)
        }
        let elapsed = lastTime.map { max(0, start - $0) } ?? 1 / 60
        let accepted = min(elapsed, 1 / 15)
        row.droppedSimulationSeconds += elapsed - accepted
        accumulator += accepted
        lastTime = start; lastPhase = framePhase
        let simulationStart = CACurrentMediaTime()
        while accumulator >= Double(Simulation.step) {
            let input = scriptStart.map { InteractionScript.point(seconds: start - $0) } ?? touch
            let work = simulation.update(touch: input)
            row.simulationSteps += 1; row.updated += work.updated; row.hitTests += work.hitTests
            accumulator -= Double(Simulation.step)
        }
        row.simulationMS.append((CACurrentMediaTime() - simulationStart) * 1000)
        let buffer = buffers[bufferIndex]
        bufferIndex = (bufferIndex + 1) % 3
        simulation.writeVertices(to: UnsafeMutableBufferPointer(
            start: buffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: simulation.homes.count),
            count: simulation.homes.count))
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            inFlight.signal(); return
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        var aspect = SIMD2<Float>(1, Float(view.drawableSize.width / max(1, view.drawableSize.height)))
        encoder.setVertexBytes(&aspect, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6,
                               instanceCount: simulation.homes.count)
        encoder.endEncoding()
        command.present(drawable)
        let semaphore = inFlight
        let token = generation
        command.addCompletedHandler { [weak self] completed in
            let duration = max(0, completed.gpuEndTime - completed.gpuStartTime) * 1000
            let failed = completed.status == .error
            semaphore.signal()
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if failed { self.lastError = "Metal command failed" }
                self.lastGPU = duration
                self.samples[framePhase, default: PhaseSamples()].gpuMS.append(duration)
            }
        }
        command.commit()
        lastCPU = (CACurrentMediaTime() - start) * 1000
        row.frames += 1; row.cpuMS.append(lastCPU)
        samples[framePhase] = row
        totalFrames += 1
        if totalFrames == 1 { firstFrameMS = (CACurrentMediaTime() - loadStart) * 1000 }
        os_signpost(.end, log: logger, name: "DotLab frame")
        if mode != .continuous && !simulation.hasActivity && touch == nil && scriptStart == nil {
            view.isPaused = true; lastTime = nil
        }
    }

    enum RendererError: Error { case unavailable, allocationFailed }
}

struct ParticleCanvas: UIViewRepresentable {
    let renderer: ParticleRenderer
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        renderer.configure(view)
        return view
    }
    func updateUIView(_ uiView: MTKView, context: Context) {}
    static func dismantleUIView(_ uiView: MTKView, coordinator: ()) {
        uiView.isPaused = true; uiView.delegate = nil
    }
}
