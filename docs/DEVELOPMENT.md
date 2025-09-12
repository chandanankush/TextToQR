# Development Guide

## Prerequisites

- macOS with Xcode (14 or newer recommended)
- Swift toolchain bundled with Xcode

## Open and Run

1. Open `QRCodeGenerator/QRCodeGenerator.xcodeproj` in Xcode.
2. Select the macOS app target `QRCodeGenerator`.
3. Run on “My Mac”.

## Project Layout

- `QRCodeGeneratorApp.swift`: App entry point and window configuration.
- `ContentView.swift`: UI, input handling, and generation triggers.
- `QRCodeGenerator.swift`: QR generation, scaling, CI→NS conversion.
- `NSImageView.swift`: SwiftUI wrapper to render an optional `NSImage`.
- `FileManagement.swift`: Folder tree scanning and simple read/write helpers.
- `LibraryTransfer.swift`: Export/import library to a single CSV (`.csv`).
- `Assets.xcassets`: App icons and colors.
- `QRCodeGenerator.entitlements`: Sandbox settings for the app.

## Coding Conventions

- Keep utility concerns (image gen, transforms) in `QRCodeGenerator`.
- Prefer small, composable SwiftUI views for UI concerns.
- Avoid work in view initializers; use `.onChange` or explicit actions.

## Local Tweaks

- Adjust output size: Change the scale calculation in `QRCodeGenerator.generateQRCode`.
- Error correction level: Pass `"L"`, `"M"`, `"Q"`, or `"H"`.

## Releasing

See `docs/RELEASE.md` for a lightweight release process.

## Sandbox / Permissions

- The app uses App Sandbox and saves QR text files inside the app container: `Application Support/<bundle id>/QRCodes`. Users do not select arbitrary folders for normal saving.
- Export/Import uses user-selected read/write entitlement to let you pick a single `.csv` file location.
