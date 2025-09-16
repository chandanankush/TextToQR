//
//  FileManagement.swift
//  QRCodeGenerator
//
//  Utilities for browsing and managing QR text files in folders.
//

import Foundation

struct FileNode: Identifiable, Hashable {
    let id: URL
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]? // only for directories

    init(url: URL, isDirectory: Bool, children: [FileNode]? = nil) {
        self.id = url
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }
}

enum FileScanner {
    static let allowedExtensions: Set<String> = ["txt", "qr", "qrtext"]

    // MARK: - Directory tree helpers

    static func buildTree(at root: URL) -> FileNode? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return FileNode(url: root, isDirectory: true, children: listChildren(of: root))
    }

    static func listChildren(of url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var dirs: [FileNode] = []
        var files: [FileNode] = []
        for item in items {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                let child = FileNode(url: item, isDirectory: true, children: listChildren(of: item))
                dirs.append(child)
            } else {
                if allowedExtensions.contains(item.pathExtension.lowercased()) {
                    files.append(FileNode(url: item, isDirectory: false))
                }
            }
        }
        // Sort: directories first, then files; both alphabetical
        dirs.sort { $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending }
        files.sort { $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending }
        return dirs + files
    }

    static func readText(from url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    static func writeText(_ text: String, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try text.data(using: .utf8)?.write(to: url)
    }

    // MARK: - Name sanitization

    static func sanitizeFileComponent(_ name: String) -> String {
        var base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        base = base.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "-", options: .regularExpression)
        return base
    }

    static func ensureAllowedExtension(for filename: String) -> String {
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension.lowercased()
        if allowedExtensions.contains(ext) {
            return url.lastPathComponent
        }
        let base = url.deletingPathExtension().lastPathComponent
        return (base.isEmpty ? "QRText" : base) + ".txt"
    }

    static func sanitizedFileName(_ raw: String, fallback: String) -> String {
        var candidate = sanitizeFileComponent(raw)
        if candidate.isEmpty {
            candidate = sanitizeFileComponent(fallback)
        }
        return ensureAllowedExtension(for: candidate)
    }

    static func sanitizeFolderComponent(_ name: String) -> String {
        var base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if base == "." || base == ".." { return "" }
        base = base.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "-", options: .regularExpression)
        return base
    }

    static func sanitizedFolderPath(_ rawPath: String) -> String {
        let components = rawPath.split(separator: "/").map { sanitizeFolderComponent(String($0)) }.filter { !$0.isEmpty }
        return components.joined(separator: "/")
    }
}
