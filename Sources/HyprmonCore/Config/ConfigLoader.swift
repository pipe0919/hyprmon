import Foundation
import CoreServices

public final class ConfigLoader {
    public static func loadFromDisk(at path: String) throws -> Config {
        guard FileManager.default.fileExists(atPath: path) else {
            return .default
        }
        let data = try String(contentsOfFile: path, encoding: .utf8)
        let dict = try TOMLParser.parse(data)
        return try Config.decode(from: dict)
    }

    public let path: String
    public private(set) var config: Config
    public var onChange: ((Config) -> Void)?

    private var stream: FSEventStreamRef?

    public init(path: String) throws {
        self.path = path
        self.config = try Self.loadFromDisk(at: path)
    }

    public func startWatching() {
        guard stream == nil else { return }
        let dir = (path as NSString).deletingLastPathComponent
        let paths = [dir] as CFArray
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, _, _, _ in
            guard let info = info else { return }
            let loader = Unmanaged<ConfigLoader>.fromOpaque(info).takeUnretainedValue()
            loader.handleEvent()
        }
        let s = FSEventStreamCreate(nil, callback, &ctx, paths,
                                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                    0.3,
                                    FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents
                                                              | kFSEventStreamCreateFlagNoDefer))
        if let s = s {
            FSEventStreamSetDispatchQueue(s, .main)
            FSEventStreamStart(s)
            self.stream = s
        }
    }

    public func stopWatching() {
        if let s = stream {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
            stream = nil
        }
    }

    deinit { stopWatching() }

    private func handleEvent() {
        guard let newCfg = try? Self.loadFromDisk(at: path) else {
            NSLog("hyprmon: invalid TOML, keeping previous config")
            return
        }
        if newCfg != config {
            config = newCfg
            onChange?(newCfg)
        }
    }
}
