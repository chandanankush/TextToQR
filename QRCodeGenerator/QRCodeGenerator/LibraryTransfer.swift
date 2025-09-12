//
//  LibraryTransfer.swift
//  QRCodeGenerator
//
//  Handles export/import of the app's QR text library to/from a single CSV file.
//

import Foundation
import AppKit

struct QRItem {
    let path: String // relative path within library (we use just filename for CSV schema)
    let text: String
}

extension Notification.Name {
    static let LibraryDidChange = Notification.Name("LibraryDidChange")
}

enum LibraryTransfer {

    static func appLibraryRoot() -> URL? {
        let fm = FileManager.default
        guard let base = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        let bundleID = Bundle.main.bundleIdentifier ?? "TextToQR"
        let appRoot = base.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("QRCodes", isDirectory: true)
        try? fm.createDirectory(at: appRoot, withIntermediateDirectories: true)
        return appRoot
    }

    // Build snapshot by scanning library
    static func buildSnapshot() -> [QRItem]? {
        guard let root = appLibraryRoot() else { return nil }
        let items = collectItems(at: root, root: root)
        return items
    }

    private static func collectItems(at url: URL, root: URL) -> [QRItem] {
        var results: [QRItem] = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        for case let item as URL in enumerator {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true { continue }
            if FileScanner.allowedExtensions.contains(item.pathExtension.lowercased()),
               let text = try? String(contentsOf: item, encoding: .utf8) {
                // Export using only filename for simplicity
                let filename = item.lastPathComponent
                results.append(QRItem(path: filename, text: text))
            }
        }
        return results.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    // Apply snapshot into library (overwrite existing files)
    static func applySnapshot(_ items: [QRItem]) throws {
        guard let root = appLibraryRoot() else { return }
        let fm = FileManager.default
        for item in items {
            let dest = uniqueFileURL(root: root, preferredFilename: ensureAllowedExtensionForFilename(item.path))
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try item.text.data(using: .utf8)?.write(to: dest)
        }
        NotificationCenter.default.post(name: .LibraryDidChange, object: nil)
    }

    // MARK: - UI: Export / Import via panels

    static func exportLibrary() {
        guard let items = buildSnapshot() else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["csv"]
        panel.nameFieldStringValue = defaultExportName()
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let csv = buildCSV(from: items)
                try csv.data(using: .utf8)?.write(to: url)
            } catch {
                NSSound.beep()
            }
        }
    }

    static func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["csv"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let items = parseCSVToItems(text)
                try applySnapshot(items)
            } catch {
                NSSound.beep()
            }
        }
    }

    private static func defaultExportName() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss_QRLibrary.csv"
        return f.string(from: Date())
    }

    // MARK: - CSV helpers

    // Always wrap fields in quotes and escape internal quotes
    private static func csvEscape(_ field: String) -> String {
        let doubled = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"" + doubled + "\""
    }

    private static func buildCSV(from items: [QRItem]) -> String {
        // Simple, hand-editable schema: filename,text,order
        // - No quoting required
        // - Replace newlines in text with literal \n
        var out = "filename,text,order\n"
        var order = 1
        for item in items {
            var filename = URL(fileURLWithPath: item.path).lastPathComponent
            // Avoid commas in filename to keep CSV very simple
            filename = filename.replacingOccurrences(of: ",", with: "-")
            let textEscaped = item.text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .replacingOccurrences(of: "\n", with: "\\n")
            out += filename + "," + textEscaped + "," + String(order) + "\n"
            order += 1
        }
        return out
    }

    private static func normalizeNewlines(_ s: String) -> String { s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n") }

    private static func parseCSVRows(_ csv: String) -> [[String]] {
        let s = normalizeNewlines(csv)
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var i = s.startIndex
        while i < s.endIndex {
            let ch = s[i]
            if inQuotes {
                if ch == "\"" {
                    let next = s.index(after: i)
                    if next < s.endIndex && s[next] == "\"" { // escaped quote
                        field.append("\"")
                        i = s.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                        i = s.index(after: i)
                        continue
                    }
                } else {
                    field.append(ch)
                    i = s.index(after: i)
                    continue
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                    i = s.index(after: i)
                    continue
                } else if ch == "," {
                    row.append(field)
                    field = ""
                    i = s.index(after: i)
                    continue
                } else if ch == "\n" {
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                    i = s.index(after: i)
                    continue
                } else {
                    field.append(ch)
                    i = s.index(after: i)
                    continue
                }
            }
        }
        // last field
        row.append(field)
        rows.append(row)
        return rows
    }

    private static func parseCSVToItems(_ csv: String) -> [QRItem] {
        var rows = parseCSVRows(csv)
        if let first = rows.first, first.count >= 2 {
            let h0 = first[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let h1 = first[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if (h0 == "filename" && h1 == "text") { rows.removeFirst() }
        }
        var items: [QRItem] = []
        for row in rows {
            if row.isEmpty { continue }
            let filenameRaw = row.first ?? ""
            // Join the middle columns as text to support unquoted commas in text
            var textRaw = ""
            if row.count >= 3, Int(row.last!.trimmingCharacters(in: .whitespaces)) != nil {
                textRaw = row[1..<(row.count-1)].joined(separator: ",")
            } else if row.count >= 2 {
                textRaw = row[1...].joined(separator: ",")
            } else {
                continue
            }
            let filename = sanitizeFilename(ensureAllowedExtensionForFilename(filenameRaw))
            guard !filename.isEmpty else { continue }
            let text = textRaw.replacingOccurrences(of: "\\n", with: "\n")
            items.append(QRItem(path: filename, text: text))
        }
        return items
    }

    private static func sanitizeFilename(_ name: String) -> String {
        var base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // remove any path components
        base = URL(fileURLWithPath: base).lastPathComponent
        if base.isEmpty { return "" }
        // replace illegal filename characters and commas
        base = base.replacingOccurrences(of: "[\\\\/:*?\"<>|,]", with: "-", options: .regularExpression)
        return base
    }

    private static func ensureAllowedExtensionForFilename(_ name: String) -> String {
        let url = URL(fileURLWithPath: name)
        let ext = url.pathExtension.lowercased()
        if FileScanner.allowedExtensions.contains(ext) { return url.lastPathComponent }
        if ext.isEmpty { return url.lastPathComponent + ".txt" }
        return url.deletingPathExtension().lastPathComponent + ".txt"
    }

    private static func uniqueFileURL(root: URL, preferredFilename: String) -> URL {
        var url = root.appendingPathComponent(preferredFilename)
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var i = 1
        while true {
            let candidate = root.appendingPathComponent("\(base)-\(i).\(ext)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
    }
}
