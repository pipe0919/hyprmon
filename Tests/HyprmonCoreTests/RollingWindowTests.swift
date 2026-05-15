import XCTest
@testable import HyprmonCore

final class RollingWindowTests: XCTestCase {
    func testSumsWithinWindow() {
        var w = RollingWindow(durationSeconds: 300)
        let now = Date(timeIntervalSince1970: 1_000_000)
        w.add(timestamp: now.addingTimeInterval(-100), tokens: 50)
        w.add(timestamp: now.addingTimeInterval(-50),  tokens: 30)
        w.add(timestamp: now.addingTimeInterval(-10),  tokens: 20)
        XCTAssertEqual(w.totalTokens(asOf: now), 100)
    }

    func testPrunesOldEvents() {
        var w = RollingWindow(durationSeconds: 300)
        let now = Date(timeIntervalSince1970: 1_000_000)
        w.add(timestamp: now.addingTimeInterval(-1000), tokens: 99)
        w.add(timestamp: now.addingTimeInterval(-100),  tokens: 50)
        XCTAssertEqual(w.totalTokens(asOf: now), 50)
        w.prune(asOf: now)
        XCTAssertEqual(w.eventCount, 1)
    }

    func testResetTime() throws {
        var w = RollingWindow(durationSeconds: 300)
        let now = Date(timeIntervalSince1970: 1_000_000)
        w.add(timestamp: now.addingTimeInterval(-250), tokens: 10)
        w.add(timestamp: now.addingTimeInterval(-100), tokens: 10)
        let delta = try XCTUnwrap(w.resetDate(asOf: now)?.timeIntervalSince(now))
        XCTAssertEqual(delta, 50, accuracy: 0.01)
    }

    func testResetTimeNilWhenEmpty() {
        let w = RollingWindow(durationSeconds: 300)
        XCTAssertNil(w.resetDate(asOf: Date()))
    }
}
