# Current Task — Stage 0 only: Setup and Feasibility

Follow `CLAUDE.md`, which is loaded automatically. Read `PLAN.md` fully before doing anything.
Do **Stage 0 only**. Do not start building the real UI or conversion engines.
Remember that the user is a beginner: explain each step in plain language as you go (`CLAUDE.md` §0).

## Steps

1. **Check the environment.** Run and record the output of:
   - `xcodebuild -version`
   - `xcode-select -p`
   - `swift --version`
   - `sw_vers`

   If `xcode-select -p` points to Command Line Tools instead of Xcode.app, stop and ask the user to run `sudo xcode-select -s /Applications/Xcode.app`.

2. **Inspect the repository.** Report what already exists.

3. **Initialize git** (`PLAN.md` §8.1, step A1).
   - Run `git init` if needed, and add a Swift/Xcode `.gitignore`. Explain what each part of the `.gitignore` excludes and why.
   - Make the first commit.
   - Ask the user whether the GitHub repository should be public or private (`PLAN.md` §10). Then give them steps to create it on GitHub and connect it, and push.
   - Explain the basic git commands as you use them.

4. **Xcode project.** Give the user exact click-by-click steps to create it in Xcode:
   - Template: macOS App, SwiftUI interface, Swift language, test targets included.
   - Name: WheelAnything.
   - Deployment target: macOS 14.0.

   Then stop and wait until the user confirms the project exists.

5. **Local package.** Create the local Swift package `WheelCore` and give the user steps to add it to the app target.

6. **App settings.** Set `LSUIElement` so the app has no Dock icon, and enable the App Sandbox with these entitlements:
   - user-selected files read-write
   - Downloads folder read-write
   - app-scoped bookmarks, only if current SDK documentation still requires it (verify)

   Prove the entitlements are present in the built app with `codesign -d --entitlements - <path to .app>`.

7. **Feasibility spikes.** Keep each spike small, in a clearly marked `Spikes/` area that is excluded from release builds:
   1. **Floating panel:** a borderless, non-activating floating panel with SwiftUI content. Check window level, visibility on all Spaces and over full-screen apps, and positioning on notched vs non-notched screens (use `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea`).
   2. **Drag and drop:** drop file URLs onto the panel while another app is frontmost.
   3. **Global hot key:** register one with Carbon `RegisterEventHotKey` inside the sandbox. Check what happens when the combination is already taken.
   4. **Image I/O capabilities:** list `CGImageSourceCopyTypeIdentifiers()` and `CGImageDestinationCopyTypeIdentifiers()` on this Mac. Note specifically whether WebP is readable and whether it is writable.
   5. **Output folders:**
      - Write a file to Downloads from the sandboxed app.
      - Try writing next to a dropped file *without* a folder grant. This is expected to fail; record the exact error.
      - Try again after granting the folder through `NSOpenPanel`, then save and restore a security-scoped bookmark after an app relaunch.
   6. **Vision:**
      - Run a foreground mask (`VNGenerateForegroundInstanceMaskRequest`) on a sample image and save the PNG result.
      - Run OCR (`VNRecognizeTextRequest`) on a sample image.
      - Record time and peak memory for both.
   7. **PDFKit:** build a 2-page PDF from two images, and render one page to PNG.
   8. **Tests:** confirm which test framework runs via `xcodebuild test`, and run one trivial test.
   9. **Universal build:** build Release for arm64 + x86_64 and confirm with `lipo -archs`.
   10. **StoreKit:** add a StoreKit configuration file with one non-consumable product, and confirm a local test purchase completes in a debug build.
   11. **Launch from Finder:** launch the built `.app` from Finder.

8. **Write `STAGE_0_REPORT.md`.** For every step, record:
   - Result: pass, fail, or blocked.
   - The exact commands run and their key output.
   - Anything that contradicts `PLAN.md`.
   - Anything still unverified, for example Intel hardware.

9. **Create `DEVELOPMENT_STATUS.md`.**

10. **Create `LEARNING_LOG.md`** with the Stage 0 section described in `CLAUDE.md` §0. Commit and push everything. Then stop and wait for the user.
