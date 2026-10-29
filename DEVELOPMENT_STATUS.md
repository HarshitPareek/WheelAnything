# Development Status

Last updated: 2026-10-29 · Current stage: **Stage 0 complete, waiting for go-ahead on Stage 1**

## Implemented and tested

- Xcode project (`WheelAnything/`): macOS 14.0 target, Swift 6, universal (arm64 + x86_64), agent app (`LSUIElement`), App Sandbox with user-selected files and Downloads read-write.
- `WheelCore` package with `ImageIOCapabilities` (1 test).
- Stage 0 feasibility spikes (Debug builds only) — results in `STAGE_0_REPORT.md`.
- Local StoreKit configuration with the Pro non-consumable; shared scheme.

## Implemented but not tested

- Panel repositioning when screens change (code present, never triggered).
- UI test target (template only, never run).

## Not implemented

- Everything in Stages 1–7: real pill/wheel UI, menu bar item, settings, file detection, conversion engines, output pipeline, Pro/entitlements, CI.

## Unverified assumptions

- Runs correctly on macOS 14/15 and on Intel.
- Non-notched and external displays.
- App Store signing removes `get-task-allow`.
- `Transaction.currentEntitlements` reports the purchased product.

## How to build and test

```sh
# App (Debug) and its unit tests
cd WheelAnything
xcodebuild test -project WheelAnything.xcodeproj -scheme WheelAnything \
  -destination 'platform=macOS' -only-testing:WheelAnythingTests

# WheelCore package
cd WheelCore && swift test

# A headless spike (Debug build only)
WheelAnything.app/Contents/MacOS/WheelAnything -spike imageio
```
