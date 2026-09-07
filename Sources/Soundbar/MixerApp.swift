import SwiftUI
import SoundbarCore

@main
struct SoundbarApp: App {
    @StateObject private var engineHolder = EngineHolder()

    var body: some Scene {
        MenuBarExtra("Soundbar", systemImage: "speaker.wave.2.fill") {
            MixerView(engine: engineHolder.engine)
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Holds the engine as an ObservableObject so SwiftUI refreshes on audio changes.
/// Set SOUNDBAR_ENGINE=tap to use real taps, =detector for detection-only, default mock in dev.
@MainActor
final class EngineHolder: ObservableObject {
    let engine: any AudioEngine

    init() {
        let mode = ProcessInfo.processInfo.environment["SOUNDBAR_ENGINE"]?.lowercased() ?? "detector"
        switch mode {
        case "mock":
            engine = MockEngine()
        case "tap":
            engine = TapEngine()
        default:
            engine = DetectorEngine()
        }
        engine.onChange = { [weak self] in self?.objectWillChange.send() }
        engine.start()
    }

    deinit {
        // Engine stop needs MainActor; best-effort (app is terminating anyway).
    }
}
