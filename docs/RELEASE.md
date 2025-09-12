# Release Guide

Lightweight steps to cut a release of the macOS app.

## Versioning

- Update `CHANGELOG.md` with the new version and notes.
- Tag commits using `vMAJOR.MINOR.PATCH` (e.g., `v0.1.0`).

## Build

1. In Xcode, select the `QRCodeGenerator` scheme.
2. Product → Archive.
3. Validate and export a Developer ID–signed app if you plan to distribute outside the Mac App Store.

## Notarization (outside the App Store)

- Use Xcode’s organizer to notarize during export, or use `xcrun notarytool` with your Apple ID credentials.

## Attach Binary

- Zip the `.app` bundle and attach it to the GitHub Release corresponding to the tag.

