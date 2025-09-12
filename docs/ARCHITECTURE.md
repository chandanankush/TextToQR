# Architecture

This document outlines the structure and data flow of the TextToQR macOS app.

## Modules

- QRCodeGeneratorApp (SwiftUI App)
  - Entry point. Creates a single `WindowGroup` and embeds `ContentView` with a fixed size.

- ContentView (SwiftUI View)
  - Holds two pieces of state: the input text and the generated `NSImage?`.
  - Triggers QR generation on text change and on the Render button.
  - Composes `NSImageView` to display the result.

- QRCodeGenerator (Utility struct)
  - `getQRImageUsingNew(qrcode:)` guard-returns `nil` on empty input, otherwise produces an `NSImage` by:
    1) creating a CI QR code (`CIQRCodeGenerator`),
    2) scaling to ~300×300 via `CGAffineTransform`,
    3) converting `CIImage` → `NSImage` via `NSCIImageRep`.
  - `generateQRCode(from:quality:)` accepts a string and correction level (e.g., `L`/`M`/`Q`/`H`).

- NSImageView (SwiftUI View)
  - Renders an optional `NSImage` using SwiftUI’s `Image(nsImage:)`.
  - Shows a placeholder message when `nil`.

## Data Flow

User types text → `@State qrInputtext` updates → `onChange` calls `QRCodeGenerator.getQRImageUsingNew` → `@State image` updated → `NSImageView` renders.

## Notes and Tradeoffs

- Scaling: The CI filter emits a small image. The current approach scales via an affine transform for simplicity. For the sharpest edges, consider rendering to a `CGImage` using a `CIContext` with no interpolation and drawing into an exact pixel buffer size.
- Error correction: Default is `H` (high). Making this adjustable is straightforward via a UI control bound to `generateQRCode`’s `quality` parameter.
- Naming: `NSImageView` (SwiftUI) can be mistaken for AppKit’s class. Consider renaming to `QRImageView` to avoid confusion.

