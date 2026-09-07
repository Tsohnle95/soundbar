import CoreAudio
import Foundation
import AppKit

/// Discovers processes currently doing audio output.
/// Uses kAudioHardwarePropertyProcessObjectList -> kAudioProcessPropertyPID / IsRunningOutput.
/// No taps required — safe to run without audio-capture permission.
public final class ProcessDetector: Sendable {
    public init() {}

    /// Returns procObjectID -> pid for all HAL clients.
    public func allClientProcesses() -> [(procID: AudioObjectID, pid: pid_t)] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [] }
        let n = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var procIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: n)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &dataSize, &procIDs
        )
        guard status == noErr else { return [] }

        return procIDs.compactMap { proc in
            guard proc != kAudioObjectUnknown, let pid = pid(for: proc) else { return nil }
            return (proc, pid)
        }
    }

    /// PIDs currently running output (what the mixer should show).
    public func soundingPIDs() -> [pid_t] {
        allClientProcesses().filter { isRunningOutput($0.procID) }.map { $0.pid }
    }

    /// Full rows for UI, resolving names/icons via NSRunningApplication.
    /// Must be called from main thread (uses AppKit).
    @MainActor
    public func soundingApps(saved: (String?) -> (volume: Float, muted: Bool)? = { _ in nil }) -> [AppAudioInfo] {
        let pairs = allClientProcesses().filter { isRunningOutput($0.procID) }
        var seen = Set<pid_t>()
        var out: [AppAudioInfo] = []
        for (proc, pid) in pairs {
            if seen.contains(pid) { continue }
            seen.insert(pid)
            let app = NSRunningApplication(processIdentifier: pid)
            let bundleID = app?.bundleIdentifier
            let name = app?.localizedName ?? "PID \(pid)"
            _ = proc
            var volume: Float = 1.0
            var muted = false
            if let s = saved(bundleID) { volume = s.volume; muted = s.muted }
            out.append(AppAudioInfo(pid: pid, bundleID: bundleID, appName: name, volume: volume, isMuted: muted))
        }
        return out.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    // MARK: - HAL helpers

    public func pid(for procID: AudioObjectID) -> pid_t? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        let status = AudioObjectGetPropertyData(procID, &addr, 0, nil, &size, &pid)
        guard status == noErr else { return nil }
        return pid
    }

    public func isRunningOutput(_ procID: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(procID, &addr, 0, nil, &size, &running)
        return status == noErr && running != 0
    }

    /// Translate PID -> process object (needed to build CATapDescription).
    /// Qualifier is pid_t per AudioHardware.h.
    public func processObjectID(forPID pid: pid_t) -> AudioObjectID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var procID = AudioObjectID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        var pidVar = pid
        let status = withUnsafePointer(to: &pidVar) { q -> OSStatus in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &addr,
                UInt32(MemoryLayout<pid_t>.size), q,
                &dataSize, &procID
            )
        }
        guard status == noErr, procID != kAudioObjectUnknown else { return nil }
        return procID
    }
}
