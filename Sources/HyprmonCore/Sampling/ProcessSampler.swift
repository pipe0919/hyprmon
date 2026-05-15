import Foundation
import Darwin

public final class ProcessSampler: @unchecked Sendable {
    public struct Sample: Sendable {
        public let pid: Int
        public let name: String
        public let cpuNs: UInt64        // cumulative CPU time in nanoseconds
        public let rss: UInt64          // resident size in bytes
        public let wakeups: UInt64      // interrupt + package-idle wakeups (cumulative)
        public init(pid: Int, name: String, cpuNs: UInt64, rss: UInt64, wakeups: UInt64) {
            self.pid = pid
            self.name = name
            self.cpuNs = cpuNs
            self.rss = rss
            self.wakeups = wakeups
        }
    }

    public struct Aggregate: Sendable {
        public var name: String
        public var cpuPct: Double        // fraction of one core (can exceed 1.0 on multi-core)
        public var rss: UInt64
        public var wakeupsPerSec: Double
        /// Approximates Activity Monitor's "Energy Impact": dominated by CPU% + wakeup rate.
        /// Wakeups normalized so 100/s contributes ~1.0; CPU% contributes directly.
        public var energyScore: Double { cpuPct + wakeupsPerSec / 100.0 }
    }

    private var prev: [Int: Sample] = [:]
    private var lastTickNs: UInt64 = 0

    public init() {}

    public func sample(count: Int = 5, sortBy: SortKey = .cpu) -> [Aggregate] {
        let now = Self.nowNs()
        let curr = Self.readAll()
        defer {
            prev = curr
            lastTickNs = now
        }
        guard lastTickNs > 0 else { return [] }
        let interval = max(now - lastTickNs, 1)
        return Self.top(prev: prev, curr: curr, intervalNs: interval, count: count, sortBy: sortBy)
    }

    public enum SortKey: Sendable {
        case cpu, ram, energy
    }

    public static func top(prev: [Int: Sample],
                           curr: [Int: Sample],
                           intervalNs: UInt64,
                           count: Int,
                           sortBy: SortKey = .cpu) -> [Aggregate] {
        var byName: [String: (cpuNs: UInt64, rss: UInt64, wakeups: UInt64)] = [:]
        for (pid, c) in curr {
            let p = prev[pid]
            let cpuDelta     = c.cpuNs   &- (p?.cpuNs ?? c.cpuNs)
            let wakeupsDelta = c.wakeups &- (p?.wakeups ?? c.wakeups)
            var entry = byName[c.name] ?? (0, 0, 0)
            entry.cpuNs   += cpuDelta
            entry.rss     += c.rss
            entry.wakeups += wakeupsDelta
            byName[c.name] = entry
        }
        let intervalSeconds = Double(intervalNs) / 1_000_000_000.0
        let aggs = byName.map { (name, v) -> Aggregate in
            let cpuPct = Double(v.cpuNs) / Double(intervalNs)
            let wakeupsPerSec = intervalSeconds > 0 ? Double(v.wakeups) / intervalSeconds : 0
            return Aggregate(name: name, cpuPct: cpuPct, rss: v.rss, wakeupsPerSec: wakeupsPerSec)
        }
        let sorted: [Aggregate]
        switch sortBy {
        case .cpu:    sorted = aggs.sorted { $0.cpuPct > $1.cpuPct }
        case .ram:    sorted = aggs.sorted { $0.rss > $1.rss }
        case .energy: sorted = aggs.sorted { $0.energyScore > $1.energyScore }
        }
        return sorted.prefix(count).map { $0 }
    }

    private static func readAll() -> [Int: Sample] {
        let bufSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufSize > 0 else { return [:] }
        let nPids = Int(bufSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: nPids)
        let actual = pids.withUnsafeMutableBufferPointer { buf in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buf.baseAddress, bufSize)
        }
        guard actual > 0 else { return [:] }
        let count = Int(actual) / MemoryLayout<pid_t>.size

        var out: [Int: Sample] = [:]
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var ti = proc_taskinfo()
            let tiSize = MemoryLayout<proc_taskinfo>.size
            let tiRes = withUnsafeMutablePointer(to: &ti) { ptr -> Int32 in
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, Int32(tiSize))
            }
            guard tiRes == Int32(tiSize) else { continue }

            // Best-effort wakeups via rusage v6. If unavailable (permission, etc.) treat as 0.
            var wakeups: UInt64 = 0
            var ru = rusage_info_v6()
            let ruRes: Int32 = withUnsafeMutablePointer(to: &ru) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                    proc_pid_rusage(pid, RUSAGE_INFO_V6, rebound)
                }
            }
            if ruRes == 0 {
                wakeups = ru.ri_interrupt_wkups &+ ru.ri_pkg_idle_wkups
            }

            var pathBuf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            let plen = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
            let name: String
            if plen > 0, let s = String(validatingUTF8: pathBuf) {
                name = (s as NSString).lastPathComponent
            } else {
                name = "pid:\(pid)"
            }

            out[Int(pid)] = Sample(
                pid: Int(pid),
                name: name,
                cpuNs: ti.pti_total_user &+ ti.pti_total_system,
                rss: ti.pti_resident_size,
                wakeups: wakeups
            )
        }
        return out
    }

    private static func nowNs() -> UInt64 {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return UInt64(ts.tv_sec) * 1_000_000_000 &+ UInt64(ts.tv_nsec)
    }
}
