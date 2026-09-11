import Foundation

/// CSV field-escaping per RFC 4180: values containing a comma, quote, or newline are wrapped in
/// quotes, with internal quotes doubled.
enum CSVField {
    static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// A single CSV file as rows of raw (unescaped) string fields — `write()` escapes and joins them.
struct CSVDocument {
    let filename: String
    var rows: [[String]] = []

    mutating func addRow(_ fields: [String]) {
        rows.append(fields)
    }

    /// Writes to a fresh file in the temp directory and returns its URL. `\r\n` line endings match
    /// the CSV spec and what Excel/Numbers expect.
    func write() throws -> URL {
        let csv = rows.map { $0.map(CSVField.escape).joined(separator: ",") }.joined(separator: "\r\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
