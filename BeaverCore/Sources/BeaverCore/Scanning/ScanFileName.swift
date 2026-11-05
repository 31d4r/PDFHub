import Foundation

/// Names for scanned PDFs, such as "Scan 2026-11-04 17.05".
public enum ScanFileName {
    /// `prefix` and the date and time to the minute. Dots instead of colons, which Files and
    /// Finder don't allow.
    public static func make(prefix: String, date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "\(prefix) \(formatter.string(from: date))"
    }

    /// A name someone typed, made safe for a file: no slashes or colons, no leading dot, no
    /// ".pdf" twice. `nil` when nothing is left.
    public static func sanitized(_ name: String) -> String? {
        var cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasSuffix(".pdf") {
            cleaned = String(cleaned.dropLast(4)).trimmingCharacters(in: .whitespaces)
        }
        while cleaned.hasPrefix(".") {
            cleaned.removeFirst()
        }
        return cleaned.isEmpty ? nil : cleaned
    }
}
