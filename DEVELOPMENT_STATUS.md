# Development Status

Last updated: 2026-10-30 · Current stage: **Stage 1 in progress** (Part A done; Part B steps 6–7 done)

## Implemented and tested

- Xcode project (`WheelAnything/`): macOS 14.0 target, Swift 6, universal (arm64 + x86_64), agent app (`LSUIElement`), App Sandbox with user-selected files and Downloads read-write.
- `WheelCore` package with `ImageIOCapabilities` (1 test).
- Stage 0 feasibility spikes (Debug builds only) — results in `STAGE_0_REPORT.md`.
- Local StoreKit configuration with the Pro non-consumable; shared scheme.
- CI (`.github/workflows/ci.yml`, `xcode-27` runner, Xcode 27.1): `swift format lint --strict` on every tracked Swift file, `swift test` in WheelCore, `xcodebuild build-for-testing`. Seen red on a failing test and green after the fix.
- `main` is protected: pull request required, `build-and-test` must pass, rules apply to admins; a direct push was rejected in a real test.
- `Entitlements` protocol with the Stage 1 `FreeTierEntitlements` (never Pro), 1 test.
- `FileDetector` (`WheelCore/FileDetection`): identifies PNG, JPEG, HEIC, HEIF, GIF, WebP and PDF by content, flags a wrong extension, rejects folders, empty files, damaged headers, damaged PDFs and unsupported types with a message. 12 tests on committed fixtures (`scripts/make-fixtures.swift`).

## Implemented but not tested

- Panel repositioning when screens change (code present, never triggered).
- UI test target: Xcode's template tests only (launch and launch performance). They run locally before each PR, not in CI.

## Not implemented

- Rest of Stage 1 (`TASK_STAGE_1.md` steps 8–14): action availability, state machine, pill panel, wheel UI, menu bar item, shortcut, settings.
- Stages 2–7: conversion engines, output pipeline, StoreKit purchases, batch, presets, release.

## Known limitations

- File detection does not catch an image cut off after its header (Image I/O reads pixels lazily); such files fail during conversion (Stage 2).
- File detection has no manual drag-and-drop run yet; that comes with the wheel UI (step 11).

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

# WheelCore package (what CI runs)
swift test --package-path WheelCore

# Formatting check (what CI runs)
git ls-files -z '*.swift' | xargs -0 swift format lint --strict

# A headless spike (Debug build only)
WheelAnything.app/Contents/MacOS/WheelAnything -spike imageio
```
