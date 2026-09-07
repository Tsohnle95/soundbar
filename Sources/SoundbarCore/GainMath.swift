import Foundation

/// Pure DSP helpers. Kept free of CoreAudio so they are unit-testable.
/// All realtime code paths must use these (no allocation, no locks).
public enum GainMath {
    /// Apply linear gain with mute. Clamps to [-1, 1] to avoid clipping overflow.
    @inline(__always)
    public static func applyGain(_ sample: Float, gain: Float, muted: Bool) -> Float {
        if muted || gain <= 0 { return 0 }
        let out = sample * gain
        return min(1.0, max(-1.0, out))
    }

    /// Bulk version used by IOProc. Operates in place on non-interleaved or interleaved buffers.
    public static func applyGainInPlace(
        _ ptr: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int,
        gain: Float,
        muted: Bool
    ) {
        let total = frameCount * channelCount
        if muted || gain <= 0 {
            for i in 0..<total { ptr[i] = 0 }
            return
        }
        if gain == 1.0 {
            // Still clamp, cheap pass.
            for i in 0..<total {
                let s = ptr[i]
                if s > 1.0 { ptr[i] = 1.0 } else if s < -1.0 { ptr[i] = -1.0 }
            }
            return
        }
        for i in 0..<total {
            let s = ptr[i] * gain
            ptr[i] = s > 1.0 ? 1.0 : (s < -1.0 ? -1.0 : s)
        }
    }

    public static func linearToPercent(_ gain: Float) -> Int {
        Int((gain * 100).rounded())
    }

    public static func percentToLinear(_ percent: Int) -> Float {
        min(2.0, max(0.0, Float(percent) / 100.0))
    }
}
