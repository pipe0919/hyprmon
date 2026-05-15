import Foundation

enum LaunchAgent {
    static let label = "com.pipe0919.hyprmon"

    static var plistPath: String {
        let home = NSHomeDirectory()
        return "\(home)/Library/LaunchAgents/\(label).plist"
    }

    static func install(binaryPath: String) throws {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [binaryPath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardErrorPath":  "\(NSHomeDirectory())/Library/Logs/hyprmon.log",
            "StandardOutPath":    "\(NSHomeDirectory())/Library/Logs/hyprmon.log",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let dir = (plistPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: plistPath))
        _ = shell(["/bin/launchctl", "bootstrap", "gui/\(getuid())", plistPath])
        print("Installed LaunchAgent at \(plistPath)")
    }

    static func uninstall() throws {
        _ = shell(["/bin/launchctl", "bootout", "gui/\(getuid())/\(label)"])
        if FileManager.default.fileExists(atPath: plistPath) {
            try FileManager.default.removeItem(atPath: plistPath)
        }
        print("Uninstalled LaunchAgent")
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
