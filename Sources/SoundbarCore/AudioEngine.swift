import Foundation

/// UI-facing engine abstraction. Lets MixerView run unchanged across phases:
/// mock (Phase 1) -> detector-only (Phase 2) -> real taps (Phase 3).
@MainActor
public protocol AudioEngine: AnyObject {
    var apps: [AppAudioInfo] { get }
    var devices: [AudioDeviceInfo] { get }
    var masterVolume: Float { get }
    var tapError: String? { get }
    var onChange: (() -> Void)? { get set }

    func refresh()
    func setVolume(_ volume: Float, for pid: pid_t)
    func setMuted(_ muted: Bool, for pid: pid_t)
    func setMasterVolume(_ volume: Float)
    func selectOutputDevice(_ device: AudioDeviceInfo)
    func start()
    func stop()
}
