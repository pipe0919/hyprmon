import Foundation

public struct ClaudeUsageSnapshot: Sendable {
    public var window5h: RollingWindow
    public var weekly:   RollingWindow
}

public final class ClaudeUsageReader: @unchecked Sendable {
    public let root: URL
    private var offsets: [String: UInt64] = [:]
    private var window5h = RollingWindow(durationSeconds: 5 * 3600)
    private var weekly   = RollingWindow(durationSeconds: 7 * 86400)
    private let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoParserNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")) {
        self.root = root
    }

    public func read(asOf now: Date = Date()) -> ClaudeUsageSnapshot {
        let projects = root.appendingPathComponent("projects")
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: projects, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return snapshot(now: now)
        }
        let cutoff = now.addingTimeInterval(-8 * 86400)
        while let url = walker.nextObject() as? URL {
            guard url.pathExtension == "jsonl" else { continue }
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let mtime = attrs?.contentModificationDate, mtime < cutoff { continue }
            ingest(file: url, now: now)
        }
        window5h.prune(asOf: now)
        weekly.prune(asOf: now)
        return snapshot(now: now)
    }

    private func snapshot(now: Date) -> ClaudeUsageSnapshot {
        ClaudeUsageSnapshot(window5h: window5h, weekly: weekly)
    }

    private func ingest(file: URL, now: Date) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }

        let path = file.path
        let startOffset = offsets[path] ?? 0

        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
        let from: UInt64
        if size < startOffset {
            from = 0
        } else {
            from = startOffset
        }

        try? handle.seek(toOffset: from)
        guard let data = try? handle.readToEnd() else { return }
        offsets[path] = from + UInt64(data.count)

        guard let text = String(data: data, encoding: .utf8) else { return }
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            parseLine(String(raw))
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let tsStr = obj["timestamp"] as? String,
              let ts = isoParser.date(from: tsStr) ?? isoParserNoFrac.date(from: tsStr) else { return }
        guard let msg = obj["message"] as? [String: Any],
              let usage = msg["usage"] as? [String: Any] else { return }
        let tokens =
            (usage["input_tokens"]  as? Int ?? 0) +
            (usage["output_tokens"] as? Int ?? 0) +
            (usage["cache_creation_input_tokens"] as? Int ?? 0) +
            (usage["cache_read_input_tokens"]    as? Int ?? 0)
        if tokens == 0 { return }
        window5h.add(timestamp: ts, tokens: tokens)
        weekly.add(timestamp: ts, tokens: tokens)
    }
}
