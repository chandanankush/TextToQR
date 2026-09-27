# Troubleshooting

## QR looks blurry

- The current scaling uses an affine transform on the CI image. For sharper edges, render to a pixel buffer (e.g., via `CIContext.createCGImage`) and draw with interpolation disabled.

## Nothing appears in the preview

- Ensure the input is not empty — empty input returns `nil` (placeholder text remains).
- Preview updates as you type; there is no Render button. Try a small ASCII value such as `https://example.com`.
- Non-ASCII input is rejected; text beyond 1,273 bytes is truncated.

## Build issues

- Make sure you’re opening the Xcode project at `QRCodeGenerator/QRCodeGenerator.xcodeproj`.
- Clean build folder (Shift+Cmd+K) and rebuild.
- Check your selected toolchain (Xcode default) and macOS deployment target.

## Entitlements / Sandbox

- The app has sandbox entitlements enabled. If adding file access features, update `QRCodeGenerator.entitlements` accordingly.

