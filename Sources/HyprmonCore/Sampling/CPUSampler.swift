import Foundation
import Darwin

public final class CPUSampler: @unchecked Sendable {
    public struct Snapshot: Equatable, Sendable {
        public var user: UInt64
        public var system: UInt64
        public var idle: UInt64
        public var nice: UInt64
    }

    private var last: Snapshot?

    public init() {}

    /// Returns CPU usage as fraction 0...1, or nil if no previous sample.
    public func sample() -> Double? {
        guard let snap = Self.readHost() else { return nil }
        defer { last = snap }
        guard let prev = last else { return nil }
        return Self.percentage(from: prev, to: snap)
    }

    public static func percentage(from prev: Snapshot, to curr: Snapshot) -> Double {
        let userΔ   = Double(curr.user   &- prev.user)
        let systemΔ = Double(curr.system &- prev.system)
        let niceΔ   = Double(curr.nice   &- prev.nice)
        let idleΔ   = Double(curr.idle   &- prev.idle)
        let used = userΔ + systemΔ + niceΔ
        let total = used + idleΔ
        return total > 0 ? used / total : 0
    }

    static func readHost() -> Snapshot? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Snapshot(
            user:   UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle:   UInt64(info.cpu_ticks.2),
            nice:   UInt64(info.cpu_ticks.3)
        )
    }
}
