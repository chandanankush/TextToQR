# TextToQR

Simple macOS SwiftUI app to generate QR codes from text using Core Image.

<img width="900" alt="sample_screenshot" src="https://github.com/chandanankush/TextToQR/assets/2377860/5b6d4bcd-e71f-41f5-9289-e4f302df9927">

Latest working app file:

[QRCodeGenerator.app.zip](https://github.com/chandanankush/TextToQR/files/14559188/QRCodeGenerator.app.zip)

## Overview

TextToQR renders a QR code for any text you type. It uses the `CIQRCodeGenerator` Core Image filter with error correction level "H", scales the image to 300×300, and displays it as an `NSImage` inside a SwiftUI view.

## Features

- Folder-based management: choose a root folder; browse subfolders/files
- Load/save QR texts as files (`.txt`, `.qr`, `.qrtext`)
- Edit and generate QR without saving; choose to Save or Save As later
- Live preview as you type (no Render button)
- Core Image–based QR generation with error correction
- Fixed-size window for a focused utility experience

## Quick Start

- Open `QRCodeGenerator/QRCodeGenerator.xcodeproj` in Xcode (macOS app target).
- Build and run.
- Click "Choose Root Folder" to point the app at a directory containing your team's QR text files (supports subfolders).
- Start typing to generate a QR without saving; click Save or Save As to persist.
- Or select a file to load and regenerate its QR; edit and Save to update that file.

See `docs/DEVELOPMENT.md` for detailed setup instructions.

## Architecture

- `QRCodeGeneratorApp` initializes the main window and hosts `ContentView`.
- `ContentView` manages input state and triggers QR generation.
- `QRCodeGenerator` encapsulates QR creation, scaling, and CI→NSImage conversion.
- `NSImageView` (SwiftUI view) renders an optional `NSImage` or a placeholder.

More details in `docs/ARCHITECTURE.md`.

## Roadmap Ideas

- Export/copy/save QR image
- Adjustable size and error correction level (L/M/Q/H)
- Input validation and better empty-state UX
- Crisper scaling via `CIContext` + `CGImage` with no interpolation

## Contributing

Contributions are welcome! Please read `CONTRIBUTING.md` and open an issue to discuss substantial changes.

## Troubleshooting

Common fixes and tips are in `docs/TROUBLESHOOTING.md`.

## License

This project is licensed under the MIT License. See `LICENSE` for details.

## Links

- Repo: https://github.com/chandanankush/TextToQR
