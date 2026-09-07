import Foundation

/// Phase 2: live detection + master volume, no per-app gain yet.
/// Works without audio-capture permission. Per-app sliders persist locally
/// and apply for real once TapEngine (Phase 3) is enabled.
@MainActor
public final class DetectorEngine: AudioEngine {
    public private(set) var apps: [AppAudioInfo] = []
    public private(set) var devices: [AudioDeviceInfo] = []
    public private(set) var masterVolume: Float = 1.0
    public private(set) var tapError: String? = nil
    public var onChange: (() -> Void)?

    private let detector = ProcessDetector()
    private let devicesMgr = DeviceManager()
    private let store = PersistenceStore()
    private var volumes: [pid_t: Float] = [:]
    private var mutes: [pid_t: Bool] = [:]
    private var timer: Timer?

    public init() {}

    public func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() {
        var rows = detector.soundingApps { _ in nil }
        // Overlay session + persisted state.
        for i in rows.indices {
            let pid = rows[i].pid
            let bid = rows[i].bundleID
            if let v = volumes[pid] { rows[i].volume = v }
            else if let s = store.savedVolume(for: bid) { rows[i].volume = s }
            if let m = mutes[pid] { rows[i].isMuted = m }
            else if let s = store.savedMute(for: bid) { rows[i].isMuted = s }
        }
        // Hide user-hidden apps.
        let hidden = store.hiddenBundleIDs
        if !hidden.isEmpty {
            rows.removeAll { $0.bundleID.map { hidden.contains($0) } ?? false }
        }
        self.apps = rows
        self.devices = devicesMgr.outputDevices()
        if let mv = devicesMgr.masterVolume() { self.masterVolume = mv }
        onChange?()
    }

    public func setVolume(_ volume: Float, for pid: pid_t) {
        let v = min(2.0, max(0.0, volume))
        volumes[pid] = v
        if let i = apps.firstIndex(where: { $0.pid == pid }) {
            apps[i].volume = v
            store.saveVolume(v, for: apps[i].bundleID)
        }
        tapError = "Per-app gain needs Phase 3 taps (not active in detector mode)."
        onChange?()
    }

    public func setMuted(_ muted: Bool, for pid: pid_t) {
        mutes[pid] = muted
        if let i = apps.firstIndex(where: { $0.pid == pid }) {
            apps[i].isMuted = muted
            store.saveMute(muted, for: apps[i].bundleID)
        }
        tapError = "Per-app mute needs Phase 3 taps (not active in detector mode)."
        onChange?()
    }

    public func setMasterVolume(_ volume: Float) {
        let v = min(1.0, max(0.0, volume))
        if devicesMgr.setMasterVolume(v) { masterVolume = v }
        onChange?()
    }

    public func selectOutputDevice(_ device: AudioDeviceInfo) {
        if devicesMgr.setDefaultOutputDevice(device.id) { refresh() }
    }
}
