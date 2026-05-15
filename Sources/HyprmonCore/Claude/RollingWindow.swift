import Foundation

public struct RollingWindow: Sendable {
    public let durationSeconds: TimeInterval
    private var events: [(Date, Int)] = []

    public init(durationSeconds: TimeInterval) {
        self.durationSeconds = durationSeconds
    }

    public var eventCount: Int { events.count }

    public mutating func add(timestamp: Date, tokens: Int) {
        events.append((timestamp, tokens))
    }

    public mutating func prune(asOf now: Date) {
        let cutoff = now.addingTimeInterval(-durationSeconds)
        events.removeAll { $0.0 < cutoff }
    }

    public func totalTokens(asOf now: Date) -> Int {
        let cutoff = now.addingTimeInterval(-durationSeconds)
        return events.reduce(0) { acc, ev in ev.0 >= cutoff ? acc + ev.1 : acc }
    }

    public func resetDate(asOf now: Date) -> Date? {
        let cutoff = now.addingTimeInterval(-durationSeconds)
        let oldest = events.filter { $0.0 >= cutoff }.map { $0.0 }.min()
        return oldest.map { $0.addingTimeInterval(durationSeconds) }
    }
}
