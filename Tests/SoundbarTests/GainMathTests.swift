import XCTest
@testable import SoundbarCore

final class GainMathTests: XCTestCase {
    func testMuteYieldsSilence() {
        XCTAssertEqual(GainMath.applyGain(0.8, gain: 1.0, muted: true), 0)
        XCTAssertEqual(GainMath.applyGain(0.8, gain: 0.0, muted: false), 0)
    }

    func testUnityClamp() {
        XCTAssertEqual(GainMath.applyGain(0.5, gain: 1.0, muted: false), 0.5)
        XCTAssertEqual(GainMath.applyGain(2.0, gain: 1.0, muted: false), 1.0)
        XCTAssertEqual(GainMath.applyGain(-2.0, gain: 1.0, muted: false), -1.0)
    }

    func testGainScales() {
        XCTAssertEqual(GainMath.applyGain(0.5, gain: 0.5, muted: false), 0.25)
        XCTAssertEqual(GainMath.applyGain(0.8, gain: 2.0, muted: false), 1.0)
    }

    func testBulkMatchesScalar() {
        var buf: [Float] = [0.5, -0.5, 2.0, -2.0, 0.0]
        buf.withUnsafeMutableBufferPointer { ptr in
            GainMath.applyGainInPlace(ptr.baseAddress!, frameCount: 5, channelCount: 1, gain: 0.5, muted: false)
        }
        XCTAssertEqual(buf[0], 0.25)
        XCTAssertEqual(buf[1], -0.25)
        XCTAssertEqual(buf[2], 1.0)
        XCTAssertEqual(buf[3], -1.0)
        XCTAssertEqual(buf[4], 0.0)
    }

    func testPercentRoundTrip() {
        XCTAssertEqual(GainMath.linearToPercent(1.0), 100)
        XCTAssertEqual(GainMath.percentToLinear(50), 0.5)
        XCTAssertEqual(GainMath.percentToLinear(200), 2.0)
        XCTAssertEqual(GainMath.percentToLinear(300), 2.0)
    }
}
