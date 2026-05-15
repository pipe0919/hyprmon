import Foundation

public enum ClaudeCredentials {
    private static let keychainService = "Claude Code-credentials"
    private static let credentialsFile = "/.claude/.credentials.json"

    /// Returns the Claude Code OAuth access token, searching in order:
    /// 1. `CLAUDE_TOKEN` env var
    /// 2. macOS Keychain (`security find-generic-password -s "Claude Code-credentials" -w`)
    /// 3. `~/.claude/.credentials.json`
    public static func loadToken() -> String? {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_TOKEN"], !env.isEmpty {
            return env
        }
        if let fromKc = readKeychain() {
            return fromKc
        }
        return readCredentialsFile()
    }

    public static var isAvailable: Bool {
        loadToken() != nil
    }

    // MARK: - Keychain

    private static func readKeychain() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/security"
        task.arguments = ["find-generic-password", "-s", keychainService, "-w"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return nil }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return extractToken(fromJSONString: raw)
    }

    // MARK: - File fallback

    private static func readCredentialsFile() -> String? {
        let path = NSHomeDirectory() + credentialsFile
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        return extractToken(fromJSONString: raw)
    }

    // MARK: - JSON parsing helper

    internal static func extractToken(fromJSONString raw: String) -> String? {
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let nested = obj["claudeAiOauth"] as? [String: Any],
           let token = nested["accessToken"] as? String, !token.isEmpty {
            return token
        }
        if let token = obj["accessToken"] as? String, !token.isEmpty {
            return token
        }
        if let token = obj["token"] as? String, !token.isEmpty {
            return token
        }
        return nil
    }
}
