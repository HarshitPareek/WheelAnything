# Current Task — Stage 1 only: UI shell with real file detection

Written by Claude from `PLAN.md` §7 (Stage 1) and §8.1 (A2, A3), at the user's request, revised with the user's changes, and reviewed by the user before any code. Follow `CLAUDE.md`.
Do **Stage 1 only**: no conversion engines, no output pipeline, no StoreKit purchase logic.

## Decisions made by the user (2026-10-29)

- Work from `PLAN.md` §7.
- Default shortcut suggested at first launch: **⌃⌥⌘W**.
- Shortcut conflicts: warn when the user picks a **well-known system shortcut**, and explain in the setting that other apps' shortcuts cannot be detected.
- **Free tier is single-file only** (`PLAN.md` §2). Any action on several files is a batch and is Pro, except the two "combine" actions, which are free by definition.
- **All Pro checks go through an `Entitlements` protocol** from Stage 1 on. The Stage 1 implementation always answers "free", because purchasing does not exist yet. Stage 5 replaces it with StoreKit. No other code decides whether Pro is active.
- **"Not built yet"** messages exist only in Debug builds. In Release builds, unbuilt actions **and** Settings sections with nothing real in them are **hidden**.
- **The chosen shortcut persists across relaunch** (stored in user defaults). An unreadable stored value is treated as "no shortcut set", logged, and shown as unset in Settings, never as a crash. The first-launch offer is shown once.
- **Spikes are deleted only when their real replacement lands.** Stage 1 replaces the panel, drop and hot-key spikes. Vision, PDF, StoreKit, folder-access, Downloads and Image I/O spikes stay until their stages. Their buttons move from the spike pill to a Debug-only "Spikes" submenu in the menu bar item.
- **CI runs only tests that need no screen:** `swift test` in `WheelCore`. The app target is built in CI but its app-hosted unit tests and UI tests run only locally. This narrows `PLAN.md` §8.1 A2 ("runs all tests") on purpose, and is why app logic belongs in `WheelCore`.
- **The user writes the deliberately failing test** in Part A; Claude reviews it.
- **Before opening each PR, Claude runs the app-hosted unit tests and the UI tests locally** (the tests CI skips) and pastes the result into the PR description: passed and failed counts, and every failure with its message.

## Actions offered after a drop

The type is the **detected content type**, not the extension. "Own format" means the file is already in that format.

| Dropped | Free | Pro (badge) |
|---|---|---|
| 1 image | Convert to PNG / JPEG / HEIC (own format hidden); Image → PDF | Remove background; Extract text |
| 2+ images | Images → PDF (one page each) | Convert to PNG / JPEG / HEIC (a format is hidden only if every file already is that format); Remove background; Extract text |
| 1 PDF | PDF → Images | Extract text |
| 2+ PDFs | Combine PDFs | PDF → Images; Extract text |
| Images and PDFs mixed | Combine into one PDF | — |

Unsupported or unreadable files are listed with the reason and left out of the selection. If nothing supported remains, only the error is shown. Dropping never starts an action.

## Choices Claude proposed (accepted by the user, 2026-10-29)

1. Pro actions show a "Pro" badge. In Stage 1, tapping any action (free or Pro) shows the Debug-only "not built yet" message; the paywall comes in Stage 5.
2. In Release builds the Settings window shows only **Shortcut** and **Plan & About** (version and privacy statement) in Stage 1.
3. **Supported image inputs in v1:** PNG, JPEG, HEIC, HEIF, GIF (from `PLAN.md` §3.1, multi-frame inputs), and WebP when Image I/O reports it readable. Other formats Image I/O can read (TIFF, BMP, RAW, …) are reported as "not supported in v1". `PLAN.md` does not say either way.

## Steps

### Part A — DevOps first (branch `stage-1/plan-and-ci`, PR 1)
1. Add `.swift-format` (4-space indentation, to match Xcode) and reformat existing code once, in its own commit.
2. Add `.github/workflows/ci.yml` (`PLAN.md` §8.1 A2), running on pull requests and on pushes to `main`, on a GitHub-hosted macOS runner:
   - select Xcode 27.x explicitly; if the runner has no Xcode 27, the job fails with a clear error message naming the Xcodes it does have,
   - build the app with `xcodebuild` (no app-hosted tests),
   - run `swift test` in `WheelCore`,
   - run `swift format lint --strict` on all Swift files.
   Claude explains every line.
3. Run the app-hosted unit tests and the UI tests locally, open PR 1 with `gh` with those results in the description, and wait for CI to pass.
4. **The user writes the deliberately failing test:**
   - Where: `WheelCore/Tests/WheelCoreTests/ImageIOCapabilitiesTests.swift`, a new `@Test` in the existing struct.
   - What: build an `ImageIOCapabilities` by hand (not `.current()`), with PNG readable and nothing writable, then expect — wrongly, on purpose — that it can write PNG. The result must not depend on the Mac the test runs on.
   - Run `swift test` locally to see it fail, commit, push, and watch CI turn red on the PR. Then fix the expectation so it states the true behavior, push, and watch CI turn green. Claude reviews both versions.
5. The user merges PR 1, then protects `main` in GitHub settings (step-by-step instructions from Claude): require a pull request and require the CI check to pass.

### Part B — UI shell (branches `stage-1/<topic>`, one PR each, merged by the user)
6. **Entitlements** (`WheelCore/Entitlements`): protocol plus the always-free Stage 1 implementation, injected wherever an action's availability is decided. Tests.
7. **File detection** (`WheelCore/FileDetection`): identify files by content (UTType, Image I/O, PDFKit), report whether the content matches the extension, and give a clear reason for unsupported or unreadable files. Committed fixtures: PNG, JPEG, HEIC, PDF, a PNG renamed to `.jpg`, an unsupported file, and an empty/truncated file. Tests for each.
8. **Action availability** (`WheelCore`): the table above as code, using detection results and the entitlements protocol. Tests for every row, including "own format hidden" and "Combine PDFs only for 2+ PDFs".
9. **Wheel state machine** (`WheelCore`): states idle, expanded, filesSelected, queued, converting, success, failure, cancelled; events (click pill, Escape, click outside, hot key, drop, choose action, …); "click outside does not close while a job runs"; "dropping never starts a conversion". Tests for every transition.
10. **Pill panel** (`WheelCore/Panel`): replaces the panel and drop spikes, using the Stage 0 findings. Check that the transparent area does not block clicks to other apps.
11. **Wheel UI** (`WheelCore/UI/Wheel`): half-wheel with 2–6 slices (v1 shows Images and PDF), actions per the table, animations, every state with its own visuals and VoiceOver description, Escape and click-outside handling. Respect Reduce Motion, Reduce Transparency and Increase Contrast.
12. **Menu bar item** (app target): Open Wheel, Settings…, Quit, plus the Debug-only Spikes submenu.
13. **Shortcut** (`WheelCore/Shortcuts`): service protocol plus the Carbon implementation (replaces the hot-key spike); first-launch offer of ⌃⌥⌘W; persisted choice; Settings recorder with the known-system-shortcut warning. Tests for the warning list, saving, restoring, and an unreadable stored value.
14. **Settings skeleton** (`WheelCore/UI/Settings`): the six sections (Release: only those with real content), keyboard navigation, accessibility labels, focus order.

## Done when (from `PLAN.md` §7)

- State-transition and action-availability tests pass.
- Drag-and-drop correctly identifies PNG, JPEG, HEIC, PDF, a renamed file with a wrong extension, and an unsupported file, with tests and a manual run.
- All Stage 1 work reached `main` through PRs whose CI checks passed.
- `STAGE_1_REPORT.md`, `DEVELOPMENT_STATUS.md` and the Stage 1 section of `LEARNING_LOG.md` are written. Then stop and wait for the user.
