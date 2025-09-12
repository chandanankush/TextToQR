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
}

