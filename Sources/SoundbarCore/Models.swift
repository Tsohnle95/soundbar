import CoreAudio
import Foundation

/// One sounding app row in the mixer.
public struct AppAudioInfo: Identifiable, Hashable, Sendable {
    public let pid: pid_t
    public var id: pid_t { pid }
    public var bundleID: String?
    public var appName: String
    public var volume: Float // 0.0 ... 2.0 (1.0 = 100%)
    public var isMuted: Bool

    public init(pid: pid_t, bundleID: String? = nil, appName: String, volume: Float = 1.0, isMuted: Bool = false) {
        self.pid = pid
        self.bundleID = bundleID
        self.appName = appName
        self.volume = volume
        self.isMuted = isMuted
    }
}

/// Output device for the header picker.
public struct AudioDeviceInfo: Identifiable, Hashable, Sendable {
    public let id: AudioObjectID
    public var name: String
    public var uid: String
    public var isDefault: Bool

    public init(id: AudioObjectID, name: String, uid: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.uid = uid
        self.isDefault = isDefault
    }
}
