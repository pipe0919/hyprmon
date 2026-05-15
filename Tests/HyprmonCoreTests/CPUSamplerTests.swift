import XCTest
@testable import HyprmonCore

final class CPUSamplerTests: XCTestCase {
    func testComputesPercentageFromTickDeltas() {
        let prev = CPUSampler.Snapshot(user: 100, system: 100, idle: 800, nice: 0)
        let curr = CPUSampler.Snapshot(user: 700, system: 200, idle: 1000, nice: 0)
        let pct = CPUSampler.percentage(from: prev, to: curr)
        XCTAssertEqual(pct, 700.0 / 900.0, accuracy: 0.0001)
    }

    func testReturnsZeroWhenNoDelta() {
        let snap = CPUSampler.Snapshot(user: 100, system: 100, idle: 800, nice: 0)
        XCTAssertEqual(CPUSampler.percentage(from: snap, to: snap), 0.0)
    }
}
