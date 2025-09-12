//
//  LibraryTransfer.swift
//  QRCodeGenerator
//
//  Handles export/import of the app's QR text library to/from a single JSON file.
//

import Foundation
import AppKit

struct QRItem: Codable {
    let path: String // relative path within library
    let text: String
}

struct QRSnapshot: Codable {
    let version: Int
    let items: [QRItem]
}

extension Notification.Name {
    static let LibraryDidChange = Notification.Name("LibraryDidChange")
}

enum LibraryTransfer {
    static let snapshotVersion = 1

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
    static func buildSnapshot() -> QRSnapshot? {
        guard let root = appLibraryRoot() else { return nil }
        let items = collectItems(at: root, root: root)
        return QRSnapshot(version: snapshotVersion, items: items)
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
                let rel = item.path.replacingOccurrences(of: root.path + "/", with: "")
                results.append(QRItem(path: rel, text: text))
            }
        }
        return results.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    // Apply snapshot into library (overwrite existing files)
    static func applySnapshot(_ snapshot: QRSnapshot) throws {
        guard let root = appLibraryRoot() else { return }
        let fm = FileManager.default
        for item in snapshot.items {
            let dest = root.appendingPathComponent(item.path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try item.text.data(using: .utf8)?.write(to: dest)
        }
        NotificationCenter.default.post(name: .LibraryDidChange, object: nil)
    }

    // MARK: - UI: Export / Import via panels

    static func exportLibrary() {
        guard let snapshot = buildSnapshot() else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["qrjson"]
        panel.nameFieldStringValue = defaultExportName()
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url)
            } catch {
                NSSound.beep()
            }
        }
    }

    static func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["qrjson"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let snapshot = try JSONDecoder().decode(QRSnapshot.self, from: data)
                try applySnapshot(snapshot)
            } catch {
                NSSound.beep()
            }
        }
    }

    private static func defaultExportName() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss_QRLibrary.qrjson"
        return f.string(from: Date())
    }
}
