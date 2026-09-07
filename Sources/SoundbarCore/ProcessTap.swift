import CoreAudio
import Foundation

/// Realtime-safe gain cell. Single Float load/store is atomic on arm64.
/// TODO(v1): replace with Synchronization.Atomic once deployment target is macOS 15+.
public final class GainCell: @unchecked Sendable {
    nonisolated(unsafe) public var gain: Float
    nonisolated(unsafe) public var muted: Bool
    public init(gain: Float = 1.0, muted: Bool = false) {
        self.gain = gain
        self.muted = muted
    }
}

@available(macOS 14.2, *)
public enum TapFactory {
    public static func makeTap(forProcess procObj: AudioObjectID, name: String) throws -> (tapID: AudioObjectID, uuid: UUID) {
        let desc = CATapDescription(stereoMixdownOfProcesses: [procObj])
        let uuid = UUID()
        desc.uuid = uuid
        desc.muteBehavior = CATapMuteBehavior.mutedWhenTapped
        desc.isPrivate = true
        desc.name = name
        var tapID = AudioObjectID(kAudioObjectUnknown)
        let err = AudioHardwareCreateProcessTap(desc, &tapID)
        guard err == noErr, tapID != kAudioObjectUnknown else {
            throw TapError.createFailed(err)
        }
        return (tapID, uuid)
    }

    public static func destroyTap(_ tapID: AudioObjectID) {
        if tapID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyProcessTap(tapID)
        }
    }

    public static func makeAggregate(outputUID: String, tapUUID: UUID) throws -> AudioObjectID {
        let uid = "Soundbar-\(tapUUID.uuidString)"
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: uid,
            kAudioAggregateDeviceUIDKey: uid,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tapUUID.uuidString,
                kAudioSubTapDriftCompensationKey: true
            ]],
            kAudioAggregateDeviceSubDeviceListKey: [[
                kAudioSubDeviceUIDKey: outputUID
            ]],
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true
        ]
        var aggID = AudioObjectID(kAudioObjectUnknown)
        let err = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggID)
        guard err == noErr, aggID != kAudioObjectUnknown else {
            throw TapError.aggregateFailed(err)
        }
        // Aggregate may not be ready immediately — poll briefly.
        for _ in 0..<50 {
            if isAlive(aggID) { break }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return aggID
    }

    public static func destroyAggregate(_ aggID: AudioObjectID) {
        if aggID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyAggregateDevice(aggID)
        }
    }

    private static func isAlive(_ device: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var alive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &alive) == noErr && alive != 0
    }

    /// Starts an IOProc on the aggregate that copies tap input -> output applying gain.
    /// Caller must keep `cell` alive for the lifetime of the proc and call `teardownIO` on stop.
    public static func startIO(
        on aggregate: AudioObjectID,
        cell: GainCell
    ) throws -> AudioDeviceIOProcID {
        var procID: AudioDeviceIOProcID?
        // NOTE: realtime context — no locks, no allocation, no Swift ARC traffic.
        let err = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregate, nil) { _, inInput, _, outOutput, _ in
            let inABL = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInput))
            let outABL = UnsafeMutableAudioBufferListPointer(outOutput)
            let g = cell.gain
            let m = cell.muted
            let count = min(inABL.count, outABL.count)
            for i in 0..<count {
                let src = inABL[i]
                var dst = outABL[i]
                guard let s = src.mData, let d = dst.mData else { continue }
                let chans = max(1, Int(src.mNumberChannels))
                guard chans > 0, src.mDataByteSize > 0 else { continue }
                let frames = Int(src.mDataByteSize) / MemoryLayout<Float>.size / chans
                guard frames > 0 else { continue }
                let sp = s.assumingMemoryBound(to: Float.self)
                let dp = d.assumingMemoryBound(to: Float.self)
                let total = frames * chans
                if m {
                    for n in 0..<total { dp[n] = 0 }
                } else if g == 1.0 {
                    for n in 0..<total {
                        let v = sp[n]
                        dp[n] = v > 1.0 ? 1.0 : (v < -1.0 ? -1.0 : v)
                    }
                } else if g <= 0 {
                    for n in 0..<total { dp[n] = 0 }
                } else {
                    for n in 0..<total {
                        var v = sp[n] * g
                        if v > 1.0 { v = 1.0 } else if v < -1.0 { v = -1.0 }
                        dp[n] = v
                    }
                }
                dst.mDataByteSize = src.mDataByteSize
                outABL[i] = dst
            }
        }
        guard err == noErr, let procID else {
            throw TapError.ioProcFailed(err)
        }
        let startErr = AudioDeviceStart(aggregate, procID)
        guard startErr == noErr else {
            _ = AudioDeviceDestroyIOProcID(aggregate, procID)
            throw TapError.startFailed(startErr)
        }
        return procID
    }

    public static func stopIO(on aggregate: AudioObjectID, proc: AudioDeviceIOProcID) {
        _ = AudioDeviceStop(aggregate, proc)
        _ = AudioDeviceDestroyIOProcID(aggregate, proc)
    }
}

public enum TapError: Error, Sendable, CustomStringConvertible {
    case unsupportedOS
    case noProcessObject(pid_t)
    case noOutputUID
    case createFailed(OSStatus)
    case aggregateFailed(OSStatus)
    case ioProcFailed(OSStatus)
    case startFailed(OSStatus)
    case permissionDenied(OSStatus)

    public var description: String {
        switch self {
        case .unsupportedOS: return "Requires macOS 14.2+."
        case .noProcessObject(let pid): return "No HAL process object for pid \(pid)."
        case .noOutputUID: return "Cannot resolve default output UID."
        case .createFailed(let e): return describe(e, what: "AudioHardwareCreateProcessTap")
        case .aggregateFailed(let e): return describe(e, what: "AudioHardwareCreateAggregateDevice")
        case .ioProcFailed(let e): return describe(e, what: "AudioDeviceCreateIOProcID")
        case .startFailed(let e): return describe(e, what: "AudioDeviceStart")
        case .permissionDenied(let e): return "System Audio permission denied (\(e)). Enable in Settings > Privacy & Security > Screen & System Audio Recording."
        }
    }

    private func describe(_ e: OSStatus, what: String) -> String {
        if e == kAudioHardwareIllegalOperationError || e == kAudioHardwareBadObjectError {
            return "System Audio permission denied (\(e)). Enable in Settings > Privacy & Security > Screen & System Audio Recording. (\(what))"
        }
        return "\(what) failed: OSStatus \(e)"
    }
}
