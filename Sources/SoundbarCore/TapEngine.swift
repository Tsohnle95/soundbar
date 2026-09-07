import CoreAudio
import Foundation

/// Phase 3: real per-app gain via one process tap + private aggregate + IOProc per app.
/// macOS 14.2+. Falls back to detector behavior when taps unavailable (permission denial, old OS).
@MainActor
public final class TapEngine: AudioEngine {
    public private(set) var apps: [AppAudioInfo] = []
    public private(set) var devices: [AudioDeviceInfo] = []
    public private(set) var masterVolume: Float = 1.0
    public private(set) var tapError: String? = nil
    public var onChange: (() -> Void)?

    private let detector = ProcessDetector()
    private let devicesMgr = DeviceManager()
    private let store = PersistenceStore()
    private var timer: Timer?

    // Active tap state, keyed by pid.
    private struct TapState {
        var tapID: AudioObjectID
        var aggregateID: AudioObjectID
        var ioProc: AudioDeviceIOProcID?
        var cell: GainCell
        var bundleID: String?
    }
    private var taps: [pid_t: TapState] = [:]

    public init() {}

    public func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // TODO: AudioObjectAddPropertyListener for kAudioHardwarePropertyDefaultOutputDevice
        // to rebuild taps instantly on headphone plug/unplug instead of 1s poll.
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        teardownAllTaps()
    }

    public func refresh() {
        var rows = detector.soundingApps { _ in nil }
        for i in rows.indices {
            let pid = rows[i].pid
            let bid = rows[i].bundleID
            if let t = taps[pid] {
                rows[i].volume = t.cell.gain
                rows[i].isMuted = t.cell.muted
            } else if let s = store.savedVolume(for: bid) {
                rows[i].volume = s
            }
            if taps[pid] == nil, let s = store.savedMute(for: bid) {
                rows[i].isMuted = s
            }
        }
        let hidden = store.hiddenBundleIDs
        if !hidden.isEmpty {
            rows.removeAll { $0.bundleID.map { hidden.contains($0) } ?? false }
        }
        self.apps = rows
        self.devices = devicesMgr.outputDevices()
        if let mv = devicesMgr.masterVolume() { self.masterVolume = mv }
        ensureTaps()
        onChange?()
    }

    // MARK: - Controls

    public func setVolume(_ volume: Float, for pid: pid_t) {
        let v = min(2.0, max(0.0, volume))
        if let t = taps[pid] {
            t.cell.gain = v
        } else {
            ensureTap(for: pid)
            taps[pid]?.cell.gain = v
        }
        if let i = apps.firstIndex(where: { $0.pid == pid }) {
            apps[i].volume = v
            store.saveVolume(v, for: apps[i].bundleID)
        }
        onChange?()
    }

    public func setMuted(_ muted: Bool, for pid: pid_t) {
        if let t = taps[pid] {
            t.cell.muted = muted
        } else {
            ensureTap(for: pid)
            taps[pid]?.cell.muted = muted
        }
        if let i = apps.firstIndex(where: { $0.pid == pid }) {
            apps[i].isMuted = muted
            store.saveMute(muted, for: apps[i].bundleID)
        }
        onChange?()
    }

    public func setMasterVolume(_ volume: Float) {
        let v = min(1.0, max(0.0, volume))
        if devicesMgr.setMasterVolume(v) { masterVolume = v }
        onChange?()
    }

    public func selectOutputDevice(_ device: AudioDeviceInfo) {
        if devicesMgr.setDefaultOutputDevice(device.id) {
            // Output changed -> aggregates reference old UID. Rebuild all.
            rebuildAllTaps()
            refresh()
        }
    }

    // MARK: - Tap lifecycle

    private func ensureTaps() {
        guard #available(macOS 14.2, *) else {
            tapError = TapError.unsupportedOS.description
            return
        }
        let live = Set(apps.map { $0.pid })
        // Teardown dead.
        for pid in Array(taps.keys) where !live.contains(pid) {
            teardownTap(pid: pid)
        }
        // Lazily create taps only for apps that need non-default gain.
        // (Keeps orange recording indicator off when everything is at 100%.)
        for row in apps where taps[row.pid] == nil {
            let needsTap = row.volume != 1.0 || row.isMuted
            if needsTap { ensureTap(for: row.pid) }
        }
    }

    private func ensureTap(for pid: pid_t) {
        guard #available(macOS 14.2, *) else { return }
        if taps[pid] != nil { return }
        guard let procObj = detector.processObjectID(forPID: pid) else {
            tapError = TapError.noProcessObject(pid).description
            return
        }
        guard let outputUID = devicesMgr.deviceUID(for: devicesMgr.defaultOutputDevice()) else {
            tapError = TapError.noOutputUID.description
            return
        }
        let row = apps.first(where: { $0.pid == pid })
        let cell = GainCell(gain: row?.volume ?? 1.0, muted: row?.isMuted ?? false)
        do {
            let (tapID, uuid) = try TapFactory.makeTap(forProcess: procObj, name: row?.appName ?? "pid \(pid)")
            let aggID: AudioObjectID
            do {
                aggID = try TapFactory.makeAggregate(outputUID: outputUID, tapUUID: uuid)
            } catch {
                TapFactory.destroyTap(tapID)
                throw error
            }
            let proc: AudioDeviceIOProcID
            do {
                proc = try TapFactory.startIO(on: aggID, cell: cell)
            } catch {
                TapFactory.destroyAggregate(aggID)
                TapFactory.destroyTap(tapID)
                throw error
            }
            taps[pid] = TapState(tapID: tapID, aggregateID: aggID, ioProc: proc, cell: cell, bundleID: row?.bundleID)
            tapError = nil
        } catch let e as TapError {
            tapError = e.description
        } catch {
            tapError = error.localizedDescription
        }
    }

    private func teardownTap(pid: pid_t) {
        guard let t = taps.removeValue(forKey: pid) else { return }
        if #available(macOS 14.2, *) {
            if let proc = t.ioProc { TapFactory.stopIO(on: t.aggregateID, proc: proc) }
            TapFactory.destroyAggregate(t.aggregateID)
            TapFactory.destroyTap(t.tapID)
        }
    }

    private func teardownAllTaps() {
        for pid in Array(taps.keys) { teardownTap(pid: pid) }
    }

    private func rebuildAllTaps() {
        // Preserve gains across device switch.
        let saved = taps.mapValues { ($0.cell.gain, $0.cell.muted, $0.bundleID) }
        teardownAllTaps()
        for (pid, (g, m, _)) in saved {
            ensureTap(for: pid)
            taps[pid]?.cell.gain = g
            taps[pid]?.cell.muted = m
        }
    }
}
