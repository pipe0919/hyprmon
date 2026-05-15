import XCTest
@testable import HyprmonCore

final class ProcessSamplerTests: XCTestCase {
    func testTopAggregatesByNameSortsByCPU() {
        let snap1: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "Chrome", cpuNs: 1_000_000_000, rss: 100),
            2: .init(pid: 2, name: "Chrome", cpuNs: 2_000_000_000, rss: 100),
            3: .init(pid: 3, name: "Xcode",  cpuNs: 5_000_000_000, rss: 200),
            4: .init(pid: 4, name: "claude", cpuNs:   500_000_000, rss:  50),
        ]
        let snap2: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "Chrome", cpuNs: 1_300_000_000, rss: 100),
            2: .init(pid: 2, name: "Chrome", cpuNs: 2_700_000_000, rss: 100),
            3: .init(pid: 3, name: "Xcode",  cpuNs: 7_000_000_000, rss: 200),
            4: .init(pid: 4, name: "claude", cpuNs:   600_000_000, rss:  50),
        ]
        let top = ProcessSampler.top(prev: snap1, curr: snap2, intervalNs: 1_000_000_000, count: 3)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top[0].name, "Xcode")
        XCTAssertEqual(top[0].cpuPct, 2.0, accuracy: 0.001)
        XCTAssertEqual(top[1].name, "Chrome")
        XCTAssertEqual(top[1].cpuPct, 1.0, accuracy: 0.001)
        XCTAssertEqual(top[2].name, "claude")
        XCTAssertEqual(top[2].cpuPct, 0.1, accuracy: 0.001)
    }
}
