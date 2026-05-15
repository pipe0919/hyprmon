import Foundation
import Observation

@MainActor
@Observable
public final class ClaudeMonitor {
    public private(set) var tokens5h: Int = 0
    public private(set) var tokensWeekly: Int = 0
    public private(set) var resetAt5h: Date?
    public private(set) var resetAtWeekly: Date?
    public private(set) var limits: PlanLimits = .init(window5h: 880_000, weekly: 6_000_000)

    private let reader: ClaudeUsageReader
    private var timer: Timer?

    public init(reader: ClaudeUsageReader = .init()) {
        self.reader = reader
    }

    public func start(intervalMs: Int, plan: Config.Plan, claudeCfg: Config.ClaudeOpts) {
        limits = PlanLimits.forPlan(plan, custom: claudeCfg)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(intervalMs) / 1000.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
        tick()
    }

    public func stop() { timer?.invalidate(); timer = nil }

    public var fraction5h: Double {
        guard limits.window5h > 0 else { return 0 }
        return min(Double(tokens5h) / Double(limits.window5h), 1.0)
    }

    public var fractionWeekly: Double? {
        guard let w = limits.weekly, w > 0 else { return nil }
        return min(Double(tokensWeekly) / Double(w), 1.0)
    }

    private func tick() {
        let now = Date()
        let snap = reader.read(asOf: now)
        tokens5h     = snap.window5h.totalTokens(asOf: now)
        tokensWeekly = snap.weekly.totalTokens(asOf: now)
        resetAt5h     = snap.window5h.resetDate(asOf: now)
        resetAtWeekly = snap.weekly.resetDate(asOf: now)
    }
}
