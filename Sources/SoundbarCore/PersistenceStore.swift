import Foundation

/// Persists per-app volume/mute keyed by bundleID (stable across launches),
/// with PID fallback for apps without bundleID.
public final class PersistenceStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let volumeKey = "soundbar.volumes.v1"
    private let muteKey = "soundbar.mutes.v1"
    private let hiddenKey = "soundbar.hidden.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func savedVolume(for bundleID: String?) -> Float? {
        guard let id = bundleID else { return nil }
        let dict = defaults.dictionary(forKey: volumeKey) as? [String: Double]
        guard let v = dict?[id] else { return nil }
        return Float(v)
    }

    public func saveVolume(_ volume: Float, for bundleID: String?) {
        guard let id = bundleID else { return }
        var dict = defaults.dictionary(forKey: volumeKey) as? [String: Double] ?? [:]
        dict[id] = Double(volume)
        defaults.set(dict, forKey: volumeKey)
    }

    public func savedMute(for bundleID: String?) -> Bool? {
        guard let id = bundleID else { return nil }
        let dict = defaults.dictionary(forKey: muteKey) as? [String: Bool]
        return dict?[id]
    }

    public func saveMute(_ muted: Bool, for bundleID: String?) {
        guard let id = bundleID else { return }
        var dict = defaults.dictionary(forKey: muteKey) as? [String: Bool] ?? [:]
        dict[id] = muted
        defaults.set(dict, forKey: muteKey)
    }

    public var hiddenBundleIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: hiddenKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: hiddenKey) }
    }
}
