# Project Context: TextToQR

## Summary
- macOS SwiftUI utility that turns ASCII text into 300×300 QR codes using Core Image (`CIQRCodeGenerator` with level H).
- App-manages its library under `Application Support/<bundle id>/QRCodes`; no manual folder picking.
- Live preview as user types, with Save/Save As, rename, delete, subfolder creation, CSV-based import/export, and a one-click library clear option.

## Primary Targets
- Xcode project: `QRCodeGenerator/QRCodeGenerator.xcodeproj`.
- App entry: `QRCodeGeneratorApp` (`QRCodeGenerator/QRCodeGenerator/QRCodeGeneratorApp.swift`).
- Main UI: `ContentView` (`QRCodeGenerator/QRCodeGenerator/ContentView.swift`).

## Core Components
- `QRCodeGenerator`: wraps Core Image filter, scales output, converts to `NSImage` (`QRCodeGenerator/QRCodeGenerator/QRCodeGenerator.swift`).
- `FileScanner` & `FileNode`: manage tree view, UTF-8 load/save, allowed extensions (`.txt`, `.qr`, `.qrtext`) (`QRCodeGenerator/QRCodeGenerator/FileManagement.swift`).
- `LibraryTransfer`: import/export via CSV, filename sanitization, `LibraryDidChange` notification (`QRCodeGenerator/QRCodeGenerator/LibraryTransfer.swift`).
- `NSImageView`: SwiftUI wrapper to render optional `NSImage` (`QRCodeGenerator/QRCodeGenerator/NSImageView.swift`).

## User Flow (ContentView)
1. On launch, ensures library root exists, loads tree, renders QR if text preset.
2. Sidebar shows folder/file tree; selecting file loads text and regenerates QR.
3. Editor enforces ASCII-only text and 1273-byte limit (QR v40-H).
4. Actions: New (clear state), Save (overwrite current), Save As/Rename (in-app sheet), Delete (with confirm).
5. Status messages auto-clear; updates trigger `LibraryDidChange` observers.

## Import/Export CSV Schema
- Header: `folder,filename,text,order` (folder blank for root-level items; importer also accepts legacy `filename,text,order`).
- Text stores literal `\n` sequences; importer converts back to newlines.
- During import: folder paths are sanitized and recreated, filenames are normalized to allowed extensions, and name collisions resolve with numeric suffixes.

## Notable Docs & Roadmap
- Architecture overview: `docs/ARCHITECTURE.md`.
- Dev setup: `docs/DEVELOPMENT.md`.
- Release process: `docs/RELEASE.md`.
- Troubleshooting tips: `docs/TROUBLESHOOTING.md`.
- `CHANGELOG.md`: 0.1.0 initial release; next features include exporting QR images and adjustable settings.
- README showcases features, quick start, and latest build artifact.

## Quick Start Checklist
- Open project in Xcode, build & run macOS target.
- Type text to see QR preview; use Save to persist to library.
- Use File menu for Import/Export (CSV) snapshots.

## Future Opportunities
- Export/copy/save QR image.
- Adjustable image size and error correction levels L/M/Q/H.
- Input validation UX improvements; sharper scaling via `CIContext`/`CGImage`.
