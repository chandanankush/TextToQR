//
//  ContentView.swift
//  QRCodeGenerator
//
//  Created by Chandan Singh on 09/05/23.
//

import SwiftUI
import Combine
import AppKit

struct ContentView: View {
    // QR text + image
    @State private var qrInputtext = ""
    @State private var image: NSImage?
    private let maxQRBytes = 1273 // QR v40-H byte capacity (byte mode)
    @State private var limitWarning: String? = nil
    @State private var previousValidText: String = ""

    // File management (app-managed root in Application Support)
    @State private var rootFolderURL: URL?
    @State private var tree: FileNode?
    @State private var selectedFileURL: URL?
    @State private var statusMessage: String = ""
    // Name sheet (for Save As / Rename without NSSavePanel)
    @State private var showNameSheet: Bool = false
    @State private var nameSheetTitle: String = ""
    @State private var nameField: String = ""
    private enum NameAction { case saveAs, rename }
    @State private var pendingAction: NameAction? = nil
    // Delete confirmation
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar: folder tree and controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Refresh") { refreshTree() }
                        .disabled(rootFolderURL == nil)
                }
                .padding([.top, .horizontal])

                Divider()

                Group {
                    if let tree = tree {
                        List {
                            OutlineGroup(tree, children: \.children) { node in
                                HStack {
                                    Image(systemName: node.isDirectory ? "folder" : "doc.text")
                                    Text(node.url.lastPathComponent)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !node.isDirectory {
                                        selectedFileURL = node.url
                                        if let txt = FileScanner.readText(from: node.url) {
                                            qrInputtext = txt
                                            enforceLimitAndUpdate()
                                        }
                                    }
                                }
                                .contextMenu {
                                    if !node.isDirectory {
                                        Button("Rename…") {
                                            selectedFileURL = node.url
                                            renameCurrent()
                                        }
                                        Button("Delete", role: .destructive) {
                                            selectedFileURL = node.url
                                            showDeleteConfirm = true
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preparing app library…")
                            Text("Your QR files are saved in the app’s Application Support folder.")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }

                Spacer()
            }
            .frame(width: 260)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main editor + preview
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $qrInputtext)
                        .font(.body)
                        .frame(minHeight: 30, maxHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                        .onChange(of: qrInputtext) { _ in
                            enforceLimitAndUpdate()
                        }
                    if let warning = limitWarning {
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding([.top, .horizontal, .bottom])

                HStack(spacing: 12) {
                    Button("New") { newUnsaved() }
                    Button("Save") { saveCurrent() }.disabled(qrInputtext.isEmpty)
                    Button("Save As") { saveAs() }.disabled(qrInputtext.isEmpty || rootFolderURL == nil)
                    Button("Rename") { renameCurrent() }.disabled(selectedFileURL == nil)
                    if let url = selectedFileURL {
                        Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(statusMessage).font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal)

                NSImageView(image: image)
                    .padding()

                Spacer()
            }
        }
        .onAppear {
            // Ensure app root exists and load tree
            self.rootFolderURL = ensureAppRoot()
            refreshTree()
            // Initial render if any prefilled text
            image = QRCodeGenerator.getQRImageUsingNew(qrcode: qrInputtext)
            previousValidText = qrInputtext
        }
        .onReceive(NotificationCenter.default.publisher(for: .LibraryDidChange)) { _ in
            refreshTree()
        }
        .alert("Delete this file?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteCurrent() }
            Button("Cancel", role: .cancel) { showDeleteConfirm = false }
        } message: {
            if let url = selectedFileURL {
                Text(url.lastPathComponent)
            }
        }
        .sheet(isPresented: $showNameSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text(nameSheetTitle).font(.headline)
                TextField("Filename", text: $nameField)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 360)
                Text("Allowed extensions: \(Array(FileScanner.allowedExtensions).sorted().joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") { showNameSheet = false }
                    Button("Save") { performNameAction() }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Actions

    private func refreshTree() {
        guard let root = rootFolderURL else { return }
        tree = FileScanner.buildTree(at: root)
    }

    private func saveAs() {
        // Prompt for filename within app library
        nameSheetTitle = "Save As"
        nameField = suggestFileName() + ".txt"
        pendingAction = .saveAs
        showNameSheet = true
    }

    private func saveCurrent() {
        if let url = selectedFileURL {
            do {
                try FileScanner.writeText(qrInputtext, to: url)
                status("Saved \(url.lastPathComponent)")
                refreshTree()
            } catch {
                status("Save failed: \(error.localizedDescription)")
            }
        } else {
            saveAs()
        }
    }

    private func newUnsaved() {
        selectedFileURL = nil
        qrInputtext = ""
        image = nil
        status("New unsaved QR")
    }

    private func renameCurrent() {
        guard let currentURL = selectedFileURL else { return }
        nameSheetTitle = "Rename"
        nameField = currentURL.lastPathComponent
        pendingAction = .rename
        showNameSheet = true
    }

    private func deleteCurrent() {
        guard let url = selectedFileURL else { showDeleteConfirm = false; return }
        do {
            try FileManager.default.removeItem(at: url)
            selectedFileURL = nil
            qrInputtext = ""
            image = nil
            refreshTree()
            status("Deleted")
        } catch {
            status("Delete failed: \(error.localizedDescription)")
        }
        showDeleteConfirm = false
    }

    private func status(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if statusMessage == message { statusMessage = "" }
        }
    }

    private func suggestFileName() -> String {
        // Default to timestamp-based name; user can edit in the save panel
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }

    // MARK: - App folder helpers

    private func ensureAppRoot() -> URL? {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let bundleID = Bundle.main.bundleIdentifier ?? "TextToQR"
        guard let baseURL = base else { return nil }
        let appRoot = baseURL.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("QRCodes", isDirectory: true)
        do {
            try fm.createDirectory(at: appRoot, withIntermediateDirectories: true)
            return appRoot
        } catch {
            status("Could not create app folder: \(error.localizedDescription)")
            return nil
        }
    }

    private func forceIntoRoot(_ url: URL, root: URL) -> URL {
        // If user navigates outside the app root in the save panel, force saving under root with chosen filename
        let standardized = url.standardizedFileURL
        if standardized.path.hasPrefix(root.standardizedFileURL.path) {
            return standardized
        }
        return root.appendingPathComponent(url.lastPathComponent)
    }

    // MARK: - Input limit enforcement

    private func asciiByteCount(_ text: String) -> Int? {
        text.data(using: .ascii)?.count
    }

    private func truncateToMaxASCIIBytes(_ text: String, max: Int) -> String {
        var result = ""
        var count = 0
        for ch in text {
            let s = String(ch)
            guard let bytes = s.data(using: .ascii) else { break }
            if count + bytes.count > max { break }
            result.append(ch)
            count += bytes.count
        }
        return result
    }

    private func enforceLimitAndUpdate() {
        // Reject non-ASCII and enforce max byte length for current QR encoding settings
        guard let byteCount = asciiByteCount(qrInputtext) else {
            limitWarning = "Only ASCII characters are supported."
            // revert to last valid
            qrInputtext = previousValidText
            return
        }
        if byteCount > maxQRBytes {
            // Truncate and warn
            let truncated = truncateToMaxASCIIBytes(qrInputtext, max: maxQRBytes)
            qrInputtext = truncated
            limitWarning = "Exceeded max length of \(maxQRBytes) bytes. Extra text truncated."
        } else {
            limitWarning = nil
            previousValidText = qrInputtext
        }
        image = QRCodeGenerator.getQRImageUsingNew(qrcode: qrInputtext)
    }

    private func sanitizeFilename(_ name: String) -> String {
        var base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = suggestFileName() }
        // Replace illegal chars
        base = base.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "-", options: .regularExpression)
        return base
    }

    private func ensureAllowedExtension(for filename: String) -> String {
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension.lowercased()
        if FileScanner.allowedExtensions.contains(ext) { return filename }
        // default to .txt
        return url.deletingPathExtension().lastPathComponent + ".txt"
    }

    private func performNameAction() {
        guard let root = rootFolderURL, let action = pendingAction else { showNameSheet = false; return }
        let cleaned = ensureAllowedExtension(for: sanitizeFilename(nameField))
        let dest = root.appendingPathComponent(cleaned)
        do {
            switch action {
            case .saveAs:
                try FileScanner.writeText(qrInputtext, to: dest)
                selectedFileURL = dest
                status("Saved \(dest.lastPathComponent)")
            case .rename:
                if let current = selectedFileURL, current != dest {
                    try FileManager.default.moveItem(at: current, to: dest)
                    selectedFileURL = dest
                    status("Renamed to \(dest.lastPathComponent)")
                }
            }
            refreshTree()
        } catch {
            status("Operation failed: \(error.localizedDescription)")
        }
        showNameSheet = false
        pendingAction = nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
