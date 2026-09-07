import Foundation

/// Simple SPSC float ring buffer for tap -> playback handoff.
/// v0.1 uses NSLock for correctness. Realtime v1 will swap to lock-free atomics.
/// Not realtime-safe yet — do not use inside IOProc without replacing.
public final class FloatRingBuffer: @unchecked Sendable {
    private var storage: [Float]
    private let capacity: Int
    private var readPos = 0
    private var writePos = 0
    private var count = 0
    private let lock = NSLock()

    public init(capacity: Int = 8192) {
        self.capacity = max(64, capacity)
        self.storage = [Float](repeating: 0, count: self.capacity)
    }

    @discardableResult
    public func write(_ samples: UnsafePointer<Float>, frames: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        var written = 0
        for i in 0..<frames {
            if count == capacity { break } // drop oldest? v0.1 drops newest
            storage[writePos] = samples[i]
            writePos = (writePos + 1) % capacity
            count += 1
            written += 1
        }
        return written
    }

    @discardableResult
    public func read(into out: UnsafeMutablePointer<Float>, frames: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        var n = 0
        for _ in 0..<frames {
            if count == 0 { break }
            out[n] = storage[readPos]
            readPos = (readPos + 1) % capacity
            count -= 1
            n += 1
        }
        return n
    }

    public var available: Int { lock.lock(); defer { lock.unlock() }; return count }
    public func clear() { lock.lock(); defer { lock.unlock() }; readPos = 0; writePos = 0; count = 0 }
}
