# TextToQR

Simple macOS SwiftUI app to generate QR codes from text using Core Image.

<img width="1144" height="895" alt="Screenshot 2025-09-12 at 4 54 44 PM" src="https://github.com/user-attachments/assets/80334ce0-e637-4d09-bfec-590ca485e144" />


Latest working app file:

[QRCodeGenerator.app.zip](https://github.com/chandanankush/TextToQR/files/14559188/QRCodeGenerator.app.zip)

## Overview

TextToQR renders a QR code for any text you type. It uses the `CIQRCodeGenerator` Core Image filter with error correction level "H", scales the image to 300×300, and displays it as an `NSImage` inside a SwiftUI view.

## Features

- App-managed storage: files saved under Application Support in the app container (no folder selection)
- Folder-based management within the app’s library; browse subfolders/files
- Load/save QR texts as files (`.txt`, `.qr`, `.qrtext`)
- Export/Import the entire library as a single `.csv` file (File menu)
- Edit and generate QR without saving; choose to Save or Save As later
- Live preview as you type (no Render button)
- Core Image–based QR generation with error correction
- Fixed-size window for a focused utility experience

## Quick Start

- Open `QRCodeGenerator/QRCodeGenerator.xcodeproj` in Xcode (macOS app target).
- Build and run.
- The app stores QR texts under `Application Support/<bundle id>/QRCodes`.
- Start typing to generate a QR without saving; click Save or Save As to persist within the app library.
- Or select a file to load and regenerate its QR; edit and Save to update that file.
- Use File → Export Library… to save a snapshot (`.csv`), and File → Import Library… to merge from a snapshot.
  - CSV schema (simple): header `filename,text,order`. Each row has the filename only (no folders), the QR text, and a serial number for readability. Fields are quoted and quotes inside a field are doubled.

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
