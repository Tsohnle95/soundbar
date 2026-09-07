import XCTest
@testable import SoundbarCore
import Foundation

final class PersistenceTests: XCTestCase {
    func testVolumeRoundTrip() {
        let suite = UserDefaults(suiteName: "soundbar.tests.\(UUID().uuidString)")!
        let store = PersistenceStore(defaults: suite)
        XCTAssertNil(store.savedVolume(for: "com.example.app"))
        store.saveVolume(0.42, for: "com.example.app")
        XCTAssertEqual(store.savedVolume(for: "com.example.app")!, 0.42, accuracy: 0.0001)
        store.saveMute(true, for: "com.example.app")
        XCTAssertEqual(store.savedMute(for: "com.example.app"), true)
    }
}
