import XCTest
@testable import HyprmonCore

final class ProcessSamplerTests: XCTestCase {
    func testTopAggregatesByNameSortsByCPU() {
        let snap1: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "Chrome", cpuNs: 1_000_000_000, rss: 100, wakeups: 0),
            2: .init(pid: 2, name: "Chrome", cpuNs: 2_000_000_000, rss: 100, wakeups: 0),
            3: .init(pid: 3, name: "Xcode",  cpuNs: 5_000_000_000, rss: 200, wakeups: 0),
            4: .init(pid: 4, name: "claude", cpuNs:   500_000_000, rss:  50, wakeups: 0),
        ]
        let snap2: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "Chrome", cpuNs: 1_300_000_000, rss: 100, wakeups: 0),
            2: .init(pid: 2, name: "Chrome", cpuNs: 2_700_000_000, rss: 100, wakeups: 0),
            3: .init(pid: 3, name: "Xcode",  cpuNs: 7_000_000_000, rss: 200, wakeups: 0),
            4: .init(pid: 4, name: "claude", cpuNs:   600_000_000, rss:  50, wakeups: 0),
        ]
        let top = ProcessSampler.top(prev: snap1, curr: snap2, intervalNs: 1_000_000_000, count: 3, sortBy: .cpu)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top[0].name, "Xcode")
        XCTAssertEqual(top[0].cpuPct, 2.0, accuracy: 0.001)
        XCTAssertEqual(top[1].name, "Chrome")
        XCTAssertEqual(top[1].cpuPct, 1.0, accuracy: 0.001)
        XCTAssertEqual(top[2].name, "claude")
        XCTAssertEqual(top[2].cpuPct, 0.1, accuracy: 0.001)
    }

    func testTopSortsByRAM() {
        let snap1: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "A", cpuNs: 1, rss: 100, wakeups: 0),
            2: .init(pid: 2, name: "B", cpuNs: 1, rss: 500, wakeups: 0),
            3: .init(pid: 3, name: "C", cpuNs: 1, rss: 250, wakeups: 0),
        ]
        let snap2 = snap1
        let top = ProcessSampler.top(prev: snap1, curr: snap2, intervalNs: 1_000_000_000, count: 3, sortBy: .ram)
        XCTAssertEqual(top.map { $0.name }, ["B", "C", "A"])
    }

    func testTopSortsByEnergy() {
        // Energy = cpuPct + wakeupsPerSec/100. Over a 1s interval:
        //   X: cpuΔ=0.5s, wakeupsΔ=0          → cpu=0.5, w/s=0, energy=0.5
        //   Y: cpuΔ=0.0,  wakeupsΔ=200/s      → cpu=0,   w/s=200, energy=2.0
        //   Z: cpuΔ=0.1s, wakeupsΔ=50/s       → cpu=0.1, w/s=50, energy=0.6
        let snap1: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "X", cpuNs:           0, rss: 0, wakeups: 0),
            2: .init(pid: 2, name: "Y", cpuNs:           0, rss: 0, wakeups: 0),
            3: .init(pid: 3, name: "Z", cpuNs:           0, rss: 0, wakeups: 0),
        ]
        let snap2: [Int: ProcessSampler.Sample] = [
            1: .init(pid: 1, name: "X", cpuNs:   500_000_000, rss: 0, wakeups:   0),
            2: .init(pid: 2, name: "Y", cpuNs:           0,   rss: 0, wakeups: 200),
            3: .init(pid: 3, name: "Z", cpuNs:   100_000_000, rss: 0, wakeups:  50),
        ]
        let top = ProcessSampler.top(prev: snap1, curr: snap2, intervalNs: 1_000_000_000, count: 3, sortBy: .energy)
        XCTAssertEqual(top.map { $0.name }, ["Y", "Z", "X"])
    }
}
