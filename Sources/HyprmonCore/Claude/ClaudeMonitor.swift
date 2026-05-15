import Foundation
import Observation

@MainActor
@Observable
public final class ClaudeMonitor {
    public private(set) var fiveHour: ClaudeUsageWindow?
    public private(set) var weekly:   ClaudeUsageWindow?
    public private(set) var plan: String = "Unknown"
    public private(set) var lastError: String?
    public private(set) var isReachable: Bool = false

    private let client = ClaudeAPIClient()
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?

    public init() {}

    public var isAvailable: Bool { ClaudeCredentials.isAvailable }

    public var fraction5h: Double {
        guard let f = fiveHour else { return 0 }
        return min(max(f.utilization / 100.0, 0), 1)
    }

    public var fractionWeekly: Double? {
        guard let w = weekly else { return nil }
        return min(max(w.utilization / 100.0, 0), 1)
    }

    public var resetAt5h: Date? { fiveHour?.resetsAt }
    public var resetAtWeekly: Date? { weekly?.resetsAt }

    public func start(intervalMs: Int) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(intervalMs) / 1000.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
        tick()
    }

    public func stop() {
        timer?.invalidate(); timer = nil
        fetchTask?.cancel(); fetchTask = nil
    }

    private func tick() {
        fetchTask?.cancel()
        fetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    private func refresh() async {
        guard let token = ClaudeCredentials.loadToken() else {
            self.lastError = "no token"
            self.isReachable = false
            return
        }
        do {
            let usage = try await client.fetch(token: token)
            self.fiveHour = usage.fiveHour
            self.weekly = usage.weekly
            self.plan = usage.plan
            self.lastError = nil
            self.isReachable = true
        } catch let error as ClaudeAPIError {
            self.lastError = error.description
            self.isReachable = false
        } catch {
            self.lastError = error.localizedDescription
            self.isReachable = false
        }
    }
}
