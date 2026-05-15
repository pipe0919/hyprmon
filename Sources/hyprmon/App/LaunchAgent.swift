import Foundation

enum LaunchAgent {
    static let label = "com.pipe0919.hyprmon"

    static var plistPath: String {
        let home = NSHomeDirectory()
        return "\(home)/Library/LaunchAgents/\(label).plist"
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    /// Returns the binary path to register with launchctl.
    /// Prefers the Homebrew bin symlink when running from a Cellar path
    /// so upgrades to a new version do not break the agent.
    static func stableBinaryPath() -> String {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        if exe.contains("/Cellar/hyprmon/") {
            for candidate in ["/opt/homebrew/bin/hyprmon", "/usr/local/bin/hyprmon"] {
                if FileManager.default.fileExists(atPath: candidate) {
                    return candidate
                }
            }
        }
        return exe
    }

    static func install(binaryPath: String? = nil) throws {
        let path = binaryPath ?? stableBinaryPath()
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [path],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardErrorPath":  "\(NSHomeDirectory())/Library/Logs/hyprmon.log",
            "StandardOutPath":    "\(NSHomeDirectory())/Library/Logs/hyprmon.log",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let dir = (plistPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: plistPath))
        // bootstrap may fail if the agent is already loaded; that's fine.
        _ = shell(["/bin/launchctl", "bootstrap", "gui/\(getuid())", plistPath])
        NSLog("hyprmon: LaunchAgent installed at \(plistPath) → \(path)")
    }

    static func uninstall() throws {
        _ = shell(["/bin/launchctl", "bootout", "gui/\(getuid())/\(label)"])
        if FileManager.default.fileExists(atPath: plistPath) {
            try FileManager.default.removeItem(atPath: plistPath)
        }
        NSLog("hyprmon: LaunchAgent uninstalled")
    }

    @discardableResult
    private static func shell(_ args: [String]) -> Int32 {
        let task = Process()
        task.launchPath = args[0]
        task.arguments = Array(args.dropFirst())
        do { try task.run() } catch { return -1 }
        task.waitUntilExit()
        return task.terminationStatus
    }
}
