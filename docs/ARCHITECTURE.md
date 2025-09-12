# Architecture

This document outlines the structure and data flow of the TextToQR macOS app.

## Modules

- QRCodeGeneratorApp (SwiftUI App)
  - Entry point. Creates a single `WindowGroup` and embeds `ContentView` with a fixed size.

- ContentView (SwiftUI View)
  - Split layout: left sidebar for folder tree, right pane for editor + preview.
  - Manages input text, generated `NSImage?`, selected root folder, and selected file URL.
  - Triggers QR generation live on text change (no Render button).
  - Provides Save/New actions to persist QR texts to files.

- QRCodeGenerator (Utility struct)
  - `getQRImageUsingNew(qrcode:)` guard-returns `nil` on empty input, otherwise produces an `NSImage` by:
    1) creating a CI QR code (`CIQRCodeGenerator`),
    2) scaling to ~300×300 via `CGAffineTransform`,
    3) converting `CIImage` → `NSImage` via `NSCIImageRep`.
  - `generateQRCode(from:quality:)` accepts a string and correction level (e.g., `L`/`M`/`Q`/`H`).

- NSImageView (SwiftUI View)
  - Renders an optional `NSImage` using SwiftUI’s `Image(nsImage:)`.
  - Shows a placeholder message when `nil`.

- FileManagement (Utilities)
  - `FileNode` tree structure to represent folders and files.
  - `FileScanner` builds the tree from a root URL and reads/writes text files with extensions: `txt`, `qr`, `qrtext`.

## Data Flow

User selects a root folder → sidebar lists folders/files → selecting a file loads its text → `@State qrInputtext` updates → `onChange` regenerates QR → Save/New write to disk → sidebar refreshes.

## Notes and Tradeoffs

- Scaling: The CI filter emits a small image. The current approach scales via an affine transform for simplicity. For the sharpest edges, consider rendering to a `CGImage` using a `CIContext` with no interpolation and drawing into an exact pixel buffer size.
- Error correction: Default is `H` (high). Making this adjustable is straightforward via a UI control bound to `generateQRCode`’s `quality` parameter.
- Naming: `NSImageView` (SwiftUI) can be mistaken for AppKit’s class. Consider renaming to `QRImageView` to avoid confusion.
