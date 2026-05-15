import Foundation

public struct ClaudeUsageWindow: Sendable, Equatable {
    public let utilization: Double      // 0...100
    public let resetsAt: Date?
}

public struct ClaudeUsage: Sendable, Equatable {
    public let fiveHour: ClaudeUsageWindow?
    public let weekly:   ClaudeUsageWindow?
    public let weeklyOpus: ClaudeUsageWindow?
    public let plan: String   // "Pro", "Max", or "Unknown"
}

public enum ClaudeAPIError: Error, CustomStringConvertible {
    case noToken
    case unauthorized
    case rateLimited(retryAfter: Int)
    case network(String)
    case http(Int)
    case decode(String)

    public var description: String {
        switch self {
        case .noToken:                     return "no token"
        case .unauthorized:                return "token rejected"
        case .rateLimited(let r):          return "rate limited (retry in \(r)s)"
        case .network(let s):              return "network error: \(s)"
        case .http(let code):              return "HTTP \(code)"
        case .decode(let s):               return "decode error: \(s)"
        }
    }
}

public struct ClaudeAPIClient: Sendable {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    public init() {}

    public func fetch(token: String) async throws -> ClaudeUsage {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "GET"
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("claude-code/2.0.31", forHTTPHeaderField: "User-Agent")

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw ClaudeAPIError.network(error.localizedDescription)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw ClaudeAPIError.network("not an HTTP response")
        }
        switch http.statusCode {
        case 200..<300:
            return try Self.parse(data: data)
        case 401, 403:
            throw ClaudeAPIError.unauthorized
        case 429:
            let retry = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw ClaudeAPIError.rateLimited(retryAfter: max(60, retry))
        default:
            throw ClaudeAPIError.http(http.statusCode)
        }
    }

    /// Pure parsing — exposed for tests.
    public static func parse(data: Data) throws -> ClaudeUsage {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.decode("not a JSON object")
        }
        let five  = parseWindow(obj["five_hour"]      as? [String: Any])
        let week  = parseWindow(obj["seven_day"]      as? [String: Any])
        let opus  = parseWindow(obj["seven_day_opus"] as? [String: Any])

        let explicit = (obj["plan"] as? String) ?? (obj["subscription_plan"] as? String)
        let plan: String
        if let e = explicit, !e.isEmpty {
            plan = e.capitalized
        } else if let o = opus, o.utilization > 0 {
            plan = "Max"
        } else {
            plan = "Pro"
        }
        return ClaudeUsage(fiveHour: five, weekly: week, weeklyOpus: opus, plan: plan)
    }

    private static func parseWindow(_ obj: [String: Any]?) -> ClaudeUsageWindow? {
        guard let obj else { return nil }
        let util = (obj["utilization"] as? Double) ?? Double(obj["utilization"] as? Int ?? 0)
        var reset: Date? = nil
        if let s = obj["resets_at"] as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            reset = f.date(from: s) ?? {
                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                return f2.date(from: s)
            }()
        }
        return ClaudeUsageWindow(utilization: util, resetsAt: reset)
    }
}
