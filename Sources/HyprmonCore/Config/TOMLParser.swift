import Foundation

public enum TOMLError: Error, CustomStringConvertible {
    case syntax(line: Int, message: String)
    public var description: String {
        switch self {
        case .syntax(let line, let msg): return "TOML syntax error on line \(line): \(msg)"
        }
    }
}

/// Minimal TOML parser supporting strings, ints, floats, bools, tables, nested tables.
/// Does NOT support: arrays, inline tables, multiline strings, datetimes.
public enum TOMLParser {
    public static func parse(_ source: String) throws -> [String: Any] {
        var root: [String: Any] = [:]
        var currentPath: [String] = []

        for (idx, rawLine) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNo = idx + 1
            let line = stripComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let inner = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                guard !inner.isEmpty else {
                    throw TOMLError.syntax(line: lineNo, message: "empty table header")
                }
                currentPath = inner.split(separator: ".").map { $0.trimmingCharacters(in: .whitespaces) }
                ensurePath(currentPath, in: &root)
                continue
            }

            guard let eq = line.firstIndex(of: "=") else {
                throw TOMLError.syntax(line: lineNo, message: "expected '=' or table header")
            }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let raw = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                throw TOMLError.syntax(line: lineNo, message: "empty key")
            }
            let value = try parseValue(String(raw), lineNo: lineNo)
            setValue(value, at: currentPath + [key], in: &root)
        }
        return root
    }

    private static func stripComment(_ line: String) -> String {
        var inString = false
        var out = ""
        for ch in line {
            if ch == "\"" { inString.toggle() }
            if ch == "#" && !inString { break }
            out.append(ch)
        }
        return out
    }

    private static func parseValue(_ raw: String, lineNo: Int) throws -> Any {
        if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
            return String(raw.dropFirst().dropLast())
        }
        if raw == "true"  { return true }
        if raw == "false" { return false }
        if let i = Int(raw)    { return i }
        if let d = Double(raw) { return d }
        throw TOMLError.syntax(line: lineNo, message: "cannot parse value: \(raw)")
    }

    private static func ensurePath(_ path: [String], in dict: inout [String: Any]) {
        guard let head = path.first else { return }
        var sub = dict[head] as? [String: Any] ?? [:]
        if path.count == 1 {
            dict[head] = sub
        } else {
            ensurePath(Array(path.dropFirst()), in: &sub)
            dict[head] = sub
        }
    }

    private static func setValue(_ value: Any, at path: [String], in dict: inout [String: Any]) {
        guard let head = path.first else { return }
        if path.count == 1 {
            dict[head] = value
            return
        }
        var sub = dict[head] as? [String: Any] ?? [:]
        setValue(value, at: Array(path.dropFirst()), in: &sub)
        dict[head] = sub
    }
}
