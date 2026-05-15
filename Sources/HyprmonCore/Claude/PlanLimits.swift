import Foundation

public struct PlanLimits: Sendable, Equatable {
    public var window5h: Int
    public var weekly: Int?

    public static func forPlan(_ plan: Config.Plan, custom: Config.ClaudeOpts) -> PlanLimits {
        switch plan {
        case .pro:    return .init(window5h:   45_000, weekly: nil)
        case .max5:   return .init(window5h:  220_000, weekly: 1_500_000)
        case .max20:  return .init(window5h:  880_000, weekly: 6_000_000)
        case .custom:
            return .init(
                window5h: custom.window5hTokens ?? 880_000,
                weekly:   custom.windowWeeklyTokens
            )
        }
    }
}
