import SwiftUI

@main
struct DotLabApp: App {
    @StateObject private var model = LabModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LabView(model: model)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        UIApplication.shared.isIdleTimerDisabled = false
                        if model.isRunning { model.cancel(reason: "App left foreground") }
                        model.renderer?.view?.isPaused = true
                        model.renderer?.touch = nil
                    } else {
                        if model.mode == .continuous { model.renderer?.wake() }
                        if ProcessInfo.processInfo.arguments.contains("--keep-awake") {
                            UIApplication.shared.isIdleTimerDisabled = true
                        }
                    }
                }
                .task {
                    let args = ProcessInfo.processInfo.arguments
                    if args.contains("--keep-awake") { UIApplication.shared.isIdleTimerDisabled = true }
                    if args.contains("--benchmark") {
                        try? await Task.sleep(for: .seconds(2))
                        model.startSuite(quick: !args.contains("--standard"))
                    } else if args.contains("--replay") {
                        try? await Task.sleep(for: .seconds(1))
                        model.replay()
                    }
                }
        }
    }
}
