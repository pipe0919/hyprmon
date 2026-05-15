import Foundation
import Darwin

public final class MemorySampler: @unchecked Sendable {
    public struct Snapshot: Sendable {
        public var wired: UInt64
        public var active: UInt64
        public var compressed: UInt64
        public var pageSize: UInt64
        public var total: UInt64
        public var usedBytes: UInt64 { (wired + active + compressed) * pageSize }
        public var usedFraction: Double {
            total > 0 ? Double(usedBytes) / Double(total) : 0
        }
    }

    private let totalBytes: UInt64

    public init() {
        self.totalBytes = Self.readTotal()
    }

    public func sample() -> Snapshot? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        var page: vm_size_t = 0
        host_page_size(mach_host_self(), &page)
        return Snapshot(
            wired:      UInt64(stats.wire_count),
            active:     UInt64(stats.active_count),
            compressed: UInt64(stats.compressor_page_count),
            pageSize:   UInt64(page),
            total:      totalBytes
        )
    }

    private static func readTotal() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }
}
