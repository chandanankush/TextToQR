//
//  LibraryTransfer.swift
//  QRCodeGenerator
//
//  Handles export/import of the app's QR text library to/from a single CSV file.
//

import Foundation
import AppKit

struct QRItem {
    let relativePath: String // relative file path within the library
    let text: String
}

extension Notification.Name {
    static let LibraryDidChange = Notification.Name("LibraryDidChange")
    static let LibraryDidClear = Notification.Name("LibraryDidClear")
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
                let relative = relativePath(for: item, root: root)
                results.append(QRItem(relativePath: relative, text: text))
            }
        }
        return results.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
    }

    // Apply snapshot into library (overwrite existing files)
    static func applySnapshot(_ items: [QRItem]) throws {
        guard let root = appLibraryRoot() else { return }
        let fm = FileManager.default
        for item in items {
            let relativePath = sanitizedRelativePath(item.relativePath)
            guard !relativePath.isEmpty else { continue }
            let dest = uniqueFileURL(root: root, preferredRelativePath: relativePath)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard let data = item.text.data(using: .utf8) else { continue }
            try data.write(to: dest)
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

    static func clearLibrary() {
        guard let root = appLibraryRoot() else { return }
        let alert = NSAlert()
        alert.messageText = "Delete all saved QR entries?"
        alert.informativeText = "This removes every file and folder in the app library. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let fm = FileManager.default
            do {
                let contents = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [])
                for item in contents {
                    try fm.removeItem(at: item)
                }
                NotificationCenter.default.post(name: .LibraryDidClear, object: nil)
                NotificationCenter.default.post(name: .LibraryDidChange, object: nil)
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
        var lines: [String] = []
        lines.append(["folder", "filename", "text", "order"].map(csvEscape).joined(separator: ","))
        var order = 1
        for item in items {
            let parts = splitRelativePath(item.relativePath)
            let normalizedText = normalizeNewlines(item.text).replacingOccurrences(of: "\n", with: "\\n")
            let fields = [
                csvEscape(parts.folder),
                csvEscape(parts.filename),
                csvEscape(normalizedText),
                csvEscape(String(order))
            ]
            lines.append(fields.joined(separator: ","))
            order += 1
        }
        return lines.joined(separator: "\n") + "\n"
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
        guard !rows.isEmpty else { return [] }

        var folderIndex: Int? = nil
        var filenameIndex: Int = 0
        var textStartIndex: Int = 1
        var orderIndex: Int? = nil

        if let first = rows.first {
            let normalized = first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            if normalized.contains("filename") {
                if let idx = normalized.firstIndex(of: "folder") { folderIndex = idx }
                if let idx = normalized.firstIndex(of: "filename") { filenameIndex = idx }
                if let idx = normalized.firstIndex(of: "text") {
                    textStartIndex = idx
                } else {
                    textStartIndex = max(filenameIndex, folderIndex ?? filenameIndex) + 1
                }
                if let idx = normalized.firstIndex(of: "order") { orderIndex = idx }
                rows.removeFirst()
            }
        }

        var items: [QRItem] = []
        for row in rows {
            if row.isEmpty { continue }

            let filenameRaw: String
            if filenameIndex < row.count {
                filenameRaw = row[filenameIndex]
            } else {
                filenameRaw = row.first ?? ""
            }

            let folderRaw: String
            if let folderIdx = folderIndex, folderIdx < row.count {
                folderRaw = row[folderIdx]
            } else {
                folderRaw = ""
            }

            var orderColumn: Int? = nil
            if let idx = orderIndex, idx < row.count,
               Int(row[idx].trimmingCharacters(in: .whitespaces)) != nil {
                orderColumn = idx
            } else if let last = row.last,
                      Int(last.trimmingCharacters(in: .whitespaces)) != nil,
                      row.count > max(filenameIndex, (folderIndex ?? -1)) + 1 {
                orderColumn = row.count - 1
            }

            let textStartCandidate = max(textStartIndex, max(filenameIndex + 1, (folderIndex ?? -1) + 1))
            let startIndex = min(textStartCandidate, row.count)
            var endIndex = row.count
            if let orderIdx = orderColumn {
                endIndex = min(orderIdx, row.count)
            }
            if startIndex >= endIndex { continue }
            let textFields = row[startIndex..<endIndex]
            let textRaw = textFields.joined(separator: ",")

            let sanitizedFolder = FileScanner.sanitizedFolderPath(folderRaw)
            let fallbackName = filenameRaw.isEmpty ? "Imported" : filenameRaw
            let sanitizedFile = FileScanner.sanitizedFileName(filenameRaw, fallback: fallbackName)
            let relativePath: String
            if sanitizedFolder.isEmpty {
                relativePath = sanitizedFile
            } else {
                relativePath = sanitizedFolder + "/" + sanitizedFile
            }
            let text = textRaw.replacingOccurrences(of: "\\n", with: "\n")
            items.append(QRItem(relativePath: relativePath, text: text))
        }
        return items
    }

    private static func uniqueFileURL(root: URL, preferredRelativePath: String) -> URL {
        let initial = URL(fileURLWithPath: preferredRelativePath, relativeTo: root).standardizedFileURL
        let fm = FileManager.default
        if !fm.fileExists(atPath: initial.path) { return initial }
        let directory = initial.deletingLastPathComponent()
        let ext = initial.pathExtension
        let base = initial.deletingPathExtension().lastPathComponent
        var i = 1
        while true {
            let candidateName = ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let absolute = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        if absolute.hasPrefix(rootPath) {
            var relative = String(absolute.dropFirst(rootPath.count))
            if relative.hasPrefix("/") { relative.removeFirst() }
            return relative
        }
        return url.lastPathComponent
    }

    private static func splitRelativePath(_ relativePath: String) -> (folder: String, filename: String) {
        if let range = relativePath.range(of: "/", options: .backwards) {
            let folder = String(relativePath[..<range.lowerBound])
            let filename = String(relativePath[range.upperBound...])
            return (folder, filename)
        }
        return ("", relativePath)
    }

    private static func sanitizedRelativePath(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return FileScanner.sanitizedFileName("Imported", fallback: "Imported")
        }
        let components = trimmed.split(separator: "/").map(String.init)
        guard let fileComponent = components.last else {
            return FileScanner.sanitizedFileName("Imported", fallback: "Imported")
        }
        let folderComponents = components.dropLast().map { FileScanner.sanitizeFolderComponent($0) }.filter { !$0.isEmpty }
        let sanitizedFile = FileScanner.sanitizedFileName(fileComponent, fallback: fileComponent.isEmpty ? "Imported" : fileComponent)
        var parts = folderComponents
        parts.append(sanitizedFile)
        return parts.joined(separator: "/")
    }
}
