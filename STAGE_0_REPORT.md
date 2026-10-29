# Stage 0 Report — Setup and Feasibility

Date: 2026-10-27 to 2026-10-29. Machine: MacBook Air, Apple Silicon (arm64), built-in notched display, macOS 26.6.2 (25G83).

All spike results below were measured **on this one Mac only**. Nothing here proves behavior on macOS 14/15, on Intel, or on non-notched / external displays (see "Still unverified").

## Summary

| Step | Result |
|---|---|
| 1. Environment check | pass (Xcode version differs from PLAN.md, see contradictions) |
| 2. Inspect repository | pass |
| 3. Git + GitHub | pass |
| 4. Xcode project | pass |
| 5. WheelCore package | pass |
| 6. App settings (LSUIElement, sandbox, entitlements) | pass |
| 7.1 Floating panel | pass (notched screen); non-notched untested |
| 7.2 Drag and drop | pass |
| 7.3 Global hot key | pass, with an important finding about conflicts |
| 7.4 Image I/O capabilities | pass |
| 7.5 Output folders | pass |
| 7.6 Vision | pass |
| 7.7 PDFKit | pass |
| 7.8 Tests | pass |
| 7.9 Universal build | pass, with one release-signing item to re-check |
| 7.10 StoreKit | pass (purchase); `currentEntitlements` result unexplained |
| 7.11 Launch from Finder | pass |

## 1. Environment

```
$ xcodebuild -version        → Xcode 27.1, Build version 27A9275
$ xcode-select -p            → /Applications/Xcode.app/Contents/Developer
$ swift --version            → Apple Swift version 6.4 (swiftlang-6.4.0.34.1), Target: arm64-apple-macosx26.0
$ sw_vers                    → macOS 26.6.2, BuildVersion 25G83
```
SDK used for every build: `MacOSX27.0.sdk`.

## 2. Repository at start

Only `CLAUDE.md`, `PLAN.md`, `TASK_STAGE_0.md`. Not a git repository.

## 3. Git and GitHub

- `git init -b main`, `.gitignore` added (macOS junk, Xcode per-user state, build output, secrets), first commit `2b97457`.
- User chose a **public** repository; created https://github.com/HarshitPareek/WheelAnything and pushed (`* [new branch] main -> main`).
- Verified: `gh repo view` → `"visibility":"PUBLIC"`; `git status -sb` → `## main...origin/main`.

## 4. Xcode project

- Created by the user: macOS App, SwiftUI, Swift Testing with XCUITest, bundle ID `com.harshitpareek.WheelAnything`.
- Xcode 27's "New Project" creates an instant scratch project in `~/Library/Developer/Xcode/UntitledProjects/` (multi-platform, deployment target 26.6.2, Swift 5, no tests). This did not meet our needs; the classic template flow was used instead.
- Fixed and verified with `xcodebuild -showBuildSettings` for all three targets: `MACOSX_DEPLOYMENT_TARGET = 14.0`, `SWIFT_VERSION = 6.0`, `SUPPORTED_PLATFORMS = macosx`, `ARCHS = arm64 x86_64`.
- Note: the app target also has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode's new-project default), so app code is main-actor by default. The WheelCore package does not use this setting.

## 5. WheelCore package

- `WheelCore/Package.swift`: tools version 6.0 (Swift 6 mode), `.macOS(.v14)`, library `WheelCore`, test target `WheelCoreTests`.
- First real type: `ImageIOCapabilities` (runtime query of Image I/O read/write formats).
- `swift test` → `Build complete!`, `✔ Test currentSystemReadsAndWritesPNG() passed`, `Target Platform: arm64e-apple-macos14.0`.
- Added to the app target by the user; project stores it as `XCLocalSwiftPackageReference "../WheelCore"` (relative path, portable to CI). App builds with `import WheelCore`: `** BUILD SUCCEEDED **`.

## 6. App settings

- `INFOPLIST_KEY_LSUIElement = YES` → built Info.plist `LSUIElement = true`.
- Running app, from `lsappinfo list`: `type="UIElement" ... sandboxed`.
- `codesign -d --entitlements - WheelAnything.app` (Debug and Release):
  ```
  com.apple.security.app-sandbox                     true
  com.apple.security.files.downloads.read-write      true
  com.apple.security.files.user-selected.read-write  true
  com.apple.security.get-task-allow                  true   (development signing, see 7.9)
  ```
- **App-scoped bookmarks entitlement (`com.apple.security.files.bookmarks.app-scope`): not added.** Evidence: Xcode 27 has no build setting or capability for it and does not mention the key anywhere; Apple's current docs page for the key returns 404; and spike 7.5 proved bookmarks work across a relaunch without it (on macOS 26.6.2).

## 7. Spikes

Code: `WheelAnything/WheelAnything/Spikes/`, every file wrapped in `#if DEBUG`. Headless spikes run as `WheelAnything.app/Contents/MacOS/WheelAnything -spike <name>`; interactive spikes start on a normal Debug launch and log to the unified log (`/usr/bin/log show --predicate 'subsystem == "com.harshitpareek.WheelAnything" AND category == "spike"'`).

### 7.1 Floating panel — pass (notched display)
- `NSPanel`, `[.borderless, .nonactivatingPanel]`, `level = .statusBar` (logged `level=25`), `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` (logged `337`), `hidesOnDeactivate = false`, SwiftUI content via `NSHostingView`.
- Log: `SCREEN Built-in Retina Display: frame=(0,0,1470,956) visibleFrame=(0,72,1470,851) safeAreaInsets.top=32.0 notch=true auxiliaryTopLeftArea=(0,924,646,32) auxiliaryTopRightArea=(825,924,645,32)`.
- Pill top edge at y=917, below the notch line (956 − 32 = 924). User screenshot confirms it sits centered below the menu bar.
- Visible on another Space and over a full-screen app: **observed by the user** (visual check, no log evidence).
- In Swift, `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` are optional (`nil` with no notch), unlike the "empty rect" described in the Objective-C header.
- **Not tested:** non-notched display, external monitor, screen-change repositioning (code present, never triggered).
- Open design point for Stage 1: the spike panel is a fixed 380×220 transparent window; whether its transparent area blocks clicks to apps underneath was not tested.

### 7.2 Drag and drop — pass
- `DROP received 1 item(s); frontmost app: Finder; WheelAnything active: false`
- `DROP .../drop-test/parrot.heic type=public.heic read 16 bytes OK` — a drop grants read access to the dropped file.

### 7.3 Global hot key — pass, with finding
- `RegisterEventHotKey` is declared in `CarbonEvents.h` of the macOS 27 SDK (`AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER`, "Not thread safe"). Works in the sandbox with no Accessibility permission.
- `⌃⌥⌘W: status=0 (noErr)`; pressed 5× while Finder was frontmost → `HOTKEY pressed id=1; frontmost app: Finder`.
- Same combination twice in the same app → `status=-9878 (eventHotKeyExistsErr)`.
- Exclusive vs exclusive across two processes → process A `status=0`, process B `status=-9878 (eventHotKeyExistsErr)`.
- **Finding:** registering **⌘Space** (Spotlight's shortcut) returned `noErr`, and pressing it opened Spotlight **and** fired our handler. Non-exclusive registration does not detect conflicts with system or other apps' shortcuts. Stage 1's shortcut setting cannot rely on the return code to warn about conflicts.

### 7.4 Image I/O — pass
- Readable: 62 types. Writable: 22 types (full lists in the spike output).
- PNG r/w, JPEG r/w, HEIC (`public.heic`) r/w, HEIF (`public.heif`) read-only, **WebP readable = true, writable = false**.

### 7.5 Output folders — pass
- Downloads: app sees `~/Library/Containers/com.harshitpareek.WheelAnything/Data/Downloads`, which resolves to `/Users/harshitpareek/Downloads`; write + read back OK, test file removed.
- Write next to a dropped file without a folder grant (and the headless equivalent next to `PLAN.md`):
  `FAILED NSCocoaErrorDomain 513 "You don’t have permission to save the file “parrot spike-sibling.txt” in the folder “drop-test”." underlying=NSPOSIXErrorDomain 1 Operation not permitted`
- After granting the folder via `NSOpenPanel`: write next to `parrot.heic` `SUCCEEDED`; bookmark saved (828 bytes, `.withSecurityScope`).
- After a relaunch (new process 88661): `BOOKMARK resolved ... stale=false startAccessing=true`, write `SUCCEEDED`.

### 7.6 Vision — pass
Single run each, Apple Silicon, measured with `/usr/bin/time -l`:

| Spike | Time | Peak memory footprint |
|---|---|---|
| baseline (app start, no work) | 0.01 s total | 2.2 MB |
| Foreground mask (`Parrot.heic`, 512×512) | request 274 ms + mask image 136 ms; 0.47 s total | 83.9 MB |
| OCR (`VNRecognizeTextRequest`, accurate, auto language, 1200×300 rendered text) | request 269 ms; 0.30 s total | 70.1 MB |

- Mask output `parrot-no-background.png`: 512×512, 36% fully transparent, 61% opaque, 2% partial; original 0% transparent. One subject instance found.
- OCR read `"WheelAnything OCR test"` and `"Drop. Convert. Done. 2026"`, confidence 1.0, exact match.
- Sandbox allowed reading `/Library/User Pictures/Animals/Parrot.heic`.

### 7.7 PDFKit — pass
- Two images → `two-pages.pdf`; reopened `pageCount=2`.
- Page 1 rendered at 2× to PNG; reopened as 1200×800 (page 600×400 pt), as expected.

### 7.8 Tests — pass
- `xcodebuild test -scheme WheelAnything -only-testing:WheelAnythingTests` → `** TEST SUCCEEDED **`, `Test case 'WheelAnythingTests/example()' passed`. Framework: **Swift Testing** (`import Testing`).
- `swift test` in `WheelCore` → 1 Swift Testing test passed.
- UI test target exists but was **not run**.

### 7.9 Universal build — pass, one item to re-check
- Release build: `** BUILD SUCCEEDED **`; `lipo -archs` → `x86_64 arm64`; `vtool -show-build` → `minos 14.0` for both.
- `strings` on the Release binary: 0 matches for spike code (Debug: 40) — `#if DEBUG` exclusion verified.
- Release build still contains `get-task-allow = true` because `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = YES` and signing is development "Sign to Run Locally". App Store distribution signing should strip it; **unverified until Stage 7**. The A4 release-check script must check it.

### 7.10 StoreKit — pass, one open item
- `WheelAnything/WheelAnything.storekit`: non-consumable `com.harshitpareek.WheelAnything.pro`, 3.99. Not copied into the app bundle. Selected in the (now shared) scheme.
- `STOREKIT products: ["com.harshitpareek.WheelAnything.pro type=Non-Consumable price=$3.99"]`
- `STOREKIT purchase verified: id=0 product=com.harshitpareek.WheelAnything.pro` (run from Xcode, Debug).
- **Open:** the loop over `Transaction.currentEntitlements` after the purchase logged no entries. Cause unknown; investigate in Stage 5 before relying on it.
- Without the StoreKit configuration (Finder launch) the product list is empty, as expected.

### 7.11 Launch from Finder — pass
- Debug app double-clicked in Finder several times; each launch logged `PANEL shown` and the pill appeared.
- Release build from Finder was not launched (it contains no spikes, so it shows only the template window).

## Contradictions with PLAN.md

1. **Xcode version.** PLAN.md §2: "Tooling: Xcode 26.x". Installed: Xcode 27.1. Proposed fix: "Xcode 27.x (latest stable)".
2. **App-scoped bookmark entitlement.** TASK_STAGE_0 asks to add it "only if current SDK documentation still requires it". Evidence says it is not required (see §6); not added.
3. **HEIC/HEIF output.** PLAN.md §3.1 "Convert between PNG, JPEG, and HEIC/HEIF": only `public.heic` is writable; `public.heif` is read-only. Stage 2 should write HEIC and treat HEIF as input only.
4. **Shortcut conflicts.** PLAN.md §2 rightly avoids ⌥Space; the spike shows the OS will not report a conflict with another app's or the system's shortcut, so conflict warnings need another approach (Stage 1 decision).

## Still unverified / outstanding

- macOS 14.x and 15.x (only macOS 26.6.2 tested), including bookmarks without the app-scope entitlement on macOS 14.
- Intel Macs (x86_64 slice builds but never ran), including Vision foreground masks on Intel.
- Non-notched display and external monitors.
- Click-through of the transparent panel area.
- `get-task-allow` removal under App Store distribution signing.
- `Transaction.currentEntitlements` returning the purchased product.
- UI test target.

## Leftovers on this Mac (not in the repo)

- `~/Downloads/WheelAnything Spike Output/` (parrot PNG, OCR input, two-pages PDF/PNG) — safe to delete.
- The saved spike bookmark in the app's preferences (`spike.grantedFolderBookmark`).
