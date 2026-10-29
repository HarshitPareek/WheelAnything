# Current Task — Stage 1 only: UI shell with real file detection

Written by Claude from `PLAN.md` §7 (Stage 1) and §8.1 (A2, A3), at the user's request, and reviewed by the user before any code. Follow `CLAUDE.md`.
Do **Stage 1 only**: no conversion engines, no output pipeline, no StoreKit/Pro logic.

## Decisions already made by the user (2026-10-29)

- Work from `PLAN.md` §7.
- Default shortcut suggested at first launch: **⌃⌥⌘W**.
- Shortcut conflicts: warn when the user picks a **well-known system shortcut**, and explain in the setting that other apps' shortcuts cannot be detected.

## Choices Claude proposes (not specified in PLAN.md — user to confirm)

1. **Actions shown after a drop:**
   - One or more images → Convert to PNG / JPEG / HEIC, Images → PDF, Remove background (Pro), Extract text (Pro).
   - One or more PDFs → PDF → Images, Combine PDFs (2+ files), Extract text (Pro).
   - Images and PDFs mixed → Combine into one PDF only.
   - Unsupported files are listed with the reason and left out. If nothing supported remains, show only the error.
2. **Pro actions in Stage 1** show a "Pro" badge but no purchase logic (that is Stage 5). Tapping one shows the "not built yet" message, like every other action in this stage.
3. **"Not built yet" messages** appear only in Debug builds. In Release builds, actions and settings sections that are not built yet are **hidden**, so the message can never ship.
4. **Settings sections** (General, Output, Formats & Quality, Shortcut, Presets (Pro), Plan & About) all exist. In Stage 1 only **Shortcut** and **Plan & About** (version number and privacy statement) do anything real; the rest show "not built yet" (Debug only).
5. **Stage 0 spikes are deleted** once the real panel and hot key replace them. They stay in git history and `STAGE_0_REPORT.md`.

## Steps

### Part A — DevOps first (branch `stage-1/plan-and-ci`, PR 1)
1. Add `.swift-format` (4-space indentation, to match Xcode) and reformat existing code once, in its own commit.
2. Add `.github/workflows/ci.yml` (PLAN.md §8.1 A2): on pull requests and pushes to `main`, on a GitHub-hosted macOS runner:
   - select Xcode 27.x; **if the runner has no Xcode 27, stop and ask** (the project was created with Xcode 27),
   - build the app and run the unit tests with `xcodebuild`,
   - run `swift test` in `WheelCore`,
   - run `swift format lint --strict` on all Swift files.
   Explain every line to the user.
3. Open PR 1 with `gh`. Push a deliberately failing test so the user sees CI go red, then fix it and see it go green.
4. The user merges PR 1, then protects `main` in GitHub settings (step-by-step instructions from Claude): require a pull request and require the CI check to pass.

### Part B — UI shell (branches `stage-1/<topic>`, one PR each, merged by the user)
5. **File detection** (`WheelCore/FileDetection`): identify files by content, not only by extension (UTType, Image I/O, PDFKit). Report the detected type, whether it matches the extension, and a clear reason for unsupported or unreadable files. Small fixture files committed to the repo: PNG, JPEG, HEIC, PDF, a PNG renamed to `.jpg`, an unsupported file, and an empty/truncated file. Unit tests for each.
6. **Wheel state machine** (`WheelCore`): states idle, expanded, filesSelected, queued, converting, success, failure, cancelled; the events that move between them (click pill, Escape, click outside, hot key, drop, choose action, …); "click outside does not close while a job runs"; "dropping never starts a conversion". Tests for every transition.
7. **Pill panel** (`WheelCore/Panel`): replaces the spike panel, using the Stage 0 findings (non-activating, all Spaces, below the notch, repositions on screen changes). Check that the transparent area does not block clicks to other apps.
8. **Wheel UI** (`WheelCore/UI/Wheel`): half-wheel with 2–6 slices (v1 shows Images and PDF), actions per detected type, animations, every state with its own visuals and VoiceOver description, Escape and click-outside handling. Respect Reduce Motion, Reduce Transparency and Increase Contrast.
9. **Menu bar item** (app target): Open Wheel, Settings…, Quit.
10. **Shortcut** (`WheelCore/Shortcuts`): service protocol plus the Carbon implementation; first-launch offer of ⌃⌥⌘W; Settings recorder with the known-system-shortcut warning; tests for the warning list and for saving and restoring the setting.
11. **Settings skeleton** (`WheelCore/UI/Settings`): the six sections, keyboard navigation, accessibility labels, focus order.
12. Remove `Spikes/`.

## Done when (from PLAN.md §7)

- State-transition tests pass.
- Drag-and-drop correctly identifies PNG, JPEG, HEIC, PDF, a renamed file with a wrong extension, and an unsupported file, with tests and a manual run.
- All Stage 1 work reached `main` through PRs whose CI checks passed.
- `STAGE_1_REPORT.md`, `DEVELOPMENT_STATUS.md` and the Stage 1 section of `LEARNING_LOG.md` are written. Then stop and wait for the user.
