import XCTest
@testable import HyprmonCore

final class MemorySamplerTests: XCTestCase {
    func testComputesUsagePercent() {
        let s = MemorySampler.Snapshot(wired: 200, active: 300, compressed: 100, pageSize: 1, total: 1000)
        XCTAssertEqual(s.usedFraction, 0.6, accuracy: 0.0001)
    }
}
