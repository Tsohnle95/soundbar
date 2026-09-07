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
/// Bundled app defaults to real taps. Set SOUNDBAR_ENGINE=mock|detector to override for dev.
@MainActor
final class EngineHolder: ObservableObject {
    let engine: any AudioEngine

    init() {
        let mode = ProcessInfo.processInfo.environment["SOUNDBAR_ENGINE"]?.lowercased() ?? "tap"
        switch mode {
        case "mock":
            engine = MockEngine()
        case "detector":
            engine = DetectorEngine()
        default:
            engine = TapEngine()
        }
        engine.onChange = { [weak self] in self?.objectWillChange.send() }
        engine.start()
    }

    deinit {
        // Engine stop needs MainActor; best-effort (app is terminating anyway).
    }
}
