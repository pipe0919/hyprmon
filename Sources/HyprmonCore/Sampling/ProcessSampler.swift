import Foundation
import Darwin

public final class ProcessSampler: @unchecked Sendable {
    public struct Sample: Sendable {
        public let pid: Int
        public let name: String
        public let cpuNs: UInt64
        public let rss: UInt64
        public init(pid: Int, name: String, cpuNs: UInt64, rss: UInt64) {
            self.pid = pid; self.name = name; self.cpuNs = cpuNs; self.rss = rss
        }
    }

    public struct Aggregate: Sendable {
        public var name: String
        public var cpuPct: Double
        public var rss: UInt64
    }

    private var prev: [Int: Sample] = [:]
    private var lastTickNs: UInt64 = 0

    public init() {}

    public func sample(count: Int = 5) -> [Aggregate] {
        let now = Self.nowNs()
        let curr = Self.readAll()
        defer {
            prev = curr
            lastTickNs = now
        }
        guard lastTickNs > 0 else { return [] }
        let interval = max(now - lastTickNs, 1)
        return Self.top(prev: prev, curr: curr, intervalNs: interval, count: count)
    }

    public static func top(prev: [Int: Sample], curr: [Int: Sample], intervalNs: UInt64, count: Int) -> [Aggregate] {
        var byName: [String: (cpuNs: UInt64, rss: UInt64)] = [:]
        for (pid, c) in curr {
            let pNs = prev[pid]?.cpuNs ?? c.cpuNs
            let deltaNs = c.cpuNs &- pNs
            var entry = byName[c.name] ?? (0, 0)
            entry.cpuNs += deltaNs
            entry.rss   += c.rss
            byName[c.name] = entry
        }
        let aggs = byName.map { (name, v) in
            Aggregate(name: name, cpuPct: Double(v.cpuNs) / Double(intervalNs), rss: v.rss)
        }
        return aggs.sorted { $0.cpuPct > $1.cpuPct }.prefix(count).map { $0 }
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
            var info = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            let res = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, Int32(size))
            }
            guard res == Int32(size) else { continue }

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
                cpuNs: info.pti_total_user &+ info.pti_total_system,
                rss: info.pti_resident_size
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
