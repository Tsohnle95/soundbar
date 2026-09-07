import XCTest
@testable import SoundbarCore

final class RingBufferTests: XCTestCase {
    func testRoundTrip() {
        let rb = FloatRingBuffer(capacity: 16)
        var src: [Float] = [1, 2, 3, 4]
        let written = src.withUnsafeBufferPointer { ptr in
            rb.write(ptr.baseAddress!, frames: 4)
        }
        XCTAssertEqual(written, 4)
        var dst = [Float](repeating: 0, count: 4)
        let read = dst.withUnsafeMutableBufferPointer { ptr in
            rb.read(into: ptr.baseAddress!, frames: 4)
        }
        XCTAssertEqual(read, 4)
        XCTAssertEqual(dst, src)
    }

    func testOverflowDrops() {
        let rb = FloatRingBuffer(capacity: 4)
        var src: [Float] = [1, 2, 3, 4, 5, 6]
        let written = src.withUnsafeBufferPointer { ptr in
            rb.write(ptr.baseAddress!, frames: 6)
        }
        XCTAssertEqual(written, 4)
        XCTAssertEqual(rb.available, 4)
    }
}
