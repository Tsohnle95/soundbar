import Foundation

/// Phase 1: in-memory engine for UI development, previews, and `swift build` without TCC.
@MainActor
public final class MockEngine: AudioEngine {
    public var apps: [AppAudioInfo] = [
        AppAudioInfo(pid: 101, bundleID: "com.apple.Music", appName: "Music", volume: 0.8, isMuted: false),
        AppAudioInfo(pid: 202, bundleID: "com.google.Chrome", appName: "Chrome", volume: 0.4, isMuted: false),
        AppAudioInfo(pid: 303, bundleID: "us.zoom.xos", appName: "Zoom", volume: 1.0, isMuted: true),
    ]
    public var devices: [AudioDeviceInfo] = [
        AudioDeviceInfo(id: 1, name: "MacBook Pro Speakers", uid: "builtin", isDefault: true),
        AudioDeviceInfo(id: 2, name: "AirPods Pro", uid: "airpods", isDefault: false),
    ]
    public var masterVolume: Float = 0.7
    public var tapError: String? = nil
    public var onChange: (() -> Void)?

    public init() {}
    public func start() {}
    public func stop() {}
    public func refresh() { onChange?() }

    public func setVolume(_ volume: Float, for pid: pid_t) {
        guard let i = apps.firstIndex(where: { $0.pid == pid }) else { return }
        apps[i].volume = min(2.0, max(0.0, volume))
        onChange?()
    }
    public func setMuted(_ muted: Bool, for pid: pid_t) {
        guard let i = apps.firstIndex(where: { $0.pid == pid }) else { return }
        apps[i].isMuted = muted
        onChange?()
    }
    public func setMasterVolume(_ volume: Float) {
        masterVolume = min(1.0, max(0.0, volume))
        onChange?()
    }
    public func selectOutputDevice(_ device: AudioDeviceInfo) {
        devices = devices.map { d in
            var m = d; m.isDefault = (d.id == device.id); return m
        }
        onChange?()
    }
}
