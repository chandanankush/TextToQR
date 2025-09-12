//
//  ContentView.swift
//  QRCodeGenerator
//
//  Created by Chandan Singh on 09/05/23.
//

import SwiftUI
import AppKit

struct ContentView: View {
    // QR text + image
    @State private var qrInputtext = ""
    @State private var image: NSImage?

    // File management
    @State private var rootFolderURL: URL?
    @State private var tree: FileNode?
    @State private var selectedFileURL: URL?
    @State private var statusMessage: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar: folder tree and controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Choose Root Folder") { chooseRootFolder() }
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
                                            image = QRCodeGenerator.getQRImageUsingNew(qrcode: qrInputtext)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No root folder selected.")
                            Text("Click ‘Choose Root Folder’ to browse and manage QR texts.")
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
                            image = QRCodeGenerator.getQRImageUsingNew(qrcode: qrInputtext)
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
            // Initial render if any prefilled text
            image = QRCodeGenerator.getQRImageUsingNew(qrcode: qrInputtext)
        }
    }

    // MARK: - Actions

    private func chooseRootFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            rootFolderURL = url
            refreshTree()
            status("Root set to \(url.lastPathComponent)")
        }
    }

    private func refreshTree() {
        guard let root = rootFolderURL else { return }
        tree = FileScanner.buildTree(at: root)
    }

    private func saveAs() {
        guard let root = rootFolderURL else { return }
        // Ask for filename
        let savePanel = NSSavePanel()
        savePanel.directoryURL = root
        savePanel.allowedFileTypes = ["qr", "txt", "qrtext"]
        savePanel.nameFieldStringValue = suggestFileName()
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try FileScanner.writeText(qrInputtext, to: url)
                selectedFileURL = url
                refreshTree()
                status("Saved \(url.lastPathComponent)")
            } catch {
                status("Save failed: \(error.localizedDescription)")
            }
        }
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
        let panel = NSSavePanel()
        panel.directoryURL = currentURL.deletingLastPathComponent()
        panel.nameFieldStringValue = currentURL.lastPathComponent
        panel.allowedFileTypes = Array(FileScanner.allowedExtensions)
        panel.prompt = "Rename"
        if panel.runModal() == .OK, let newURL = panel.url {
            guard newURL != currentURL else { return }
            do {
                try FileManager.default.moveItem(at: currentURL, to: newURL)
                selectedFileURL = newURL
                refreshTree()
                status("Renamed to \(newURL.lastPathComponent)")
            } catch {
                status("Rename failed: \(error.localizedDescription)")
            }
        }
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
