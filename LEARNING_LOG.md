# Learning Log

## Stage 0 — Setup and feasibility

### 1. Git, commits and remotes
Git records snapshots of your project called **commits**. You choose what goes into the next snapshot with `git add` (staging), save it with `git commit -m "message"`, and look at the history with `git log`. `git status` shows what changed since the last commit. A **remote** is another copy of the repository, here on GitHub, named `origin`; `git push` uploads your commits there and `git pull` downloads new ones. `.gitignore` lists files git must never track, such as build output and secrets.
*In this project:* `.gitignore`; the Stage 0 commits on `main` (`git log --oneline`); remote `origin` → github.com/HarshitPareek/WheelAnything.

### 2. Project, targets and packages
An Xcode **project** holds one or more **targets**: each target builds one product (the app, the unit tests, the UI tests). A Swift **package** is a separate, self-contained unit of code with its own recipe (`Package.swift`) that can be built and tested on its own with `swift test`. We keep the app target thin and put real logic in the `WheelCore` package so it is easy to test and the project file stays small.
*In this project:* `WheelAnything/WheelAnything.xcodeproj` (3 targets), `WheelCore/Package.swift`, `WheelCore/Sources/WheelCore/Formats/ImageIOCapabilities.swift`.

### 3. The App Sandbox and entitlements
The **App Sandbox** is a safety cage macOS puts around App Store apps: by default the app can only touch its own private folder (its **container**). **Entitlements** are permissions the app declares, which macOS enforces. We asked for exactly two file permissions: files the user picks or drops, and the Downloads folder. Anything else fails with "Operation not permitted" (error 513) — the spike proved this. To keep access to a folder the user granted after the app restarts, we save a **security-scoped bookmark**, which we turn back into a URL and bracket with `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`.
*In this project:* sandbox settings on the app target (check with `codesign -d --entitlements -`); `Spikes/OutputSpike.swift`.

### 4. Debug vs Release, `#if DEBUG`, universal binaries
A **build configuration** is a set of settings. **Debug** is for development (fast builds, debugger); **Release** is what ships. `#if DEBUG ... #endif` tells the compiler to include code only in Debug builds — our spike code is completely absent from Release (checked with `strings`). A **universal binary** contains machine code for both Apple Silicon (`arm64`) and Intel (`x86_64`); `lipo -archs` lists which are inside.
*In this project:* every file in `WheelAnything/WheelAnything/Spikes/`; `WheelAnythingApp.swift`.

### 5. Info.plist and agent apps
Every app has an **Info.plist**, a file of basic facts macOS reads before launching it. Setting `LSUIElement` to YES makes the app an **agent**: no Dock icon, no app menu, never "the active app" unless it asks. That is why the floating panel had to be non-activating, set `hidesOnDeactivate = false`, and be shown with `orderFrontRegardless()`.
*In this project:* the "Application is Agent (UIElement)" build setting; `Spikes/PanelSpike.swift`.

### 6. Spikes: verify before you build
A **spike** is a small, throwaway experiment that answers one question with evidence before you build a feature on top of it. Several of ours changed the plan: WebP can be read but not written, `public.heif` cannot be written, the app-scoped bookmark entitlement is not needed, and the hot-key API does not report conflicts with other apps' shortcuts.
*In this project:* `STAGE_0_REPORT.md`; `Spikes/`.

### Quiz
1. You run `git add .` and then `git commit -m "Fix"`, but forget `git push`. Is your change on GitHub? Why or why not?
2. The app tries to save `photo.jpg` next to a file the user dragged in from `~/Pictures`. The user never granted that folder. What happens, and why?
3. Why is the spike code safe to leave in the repository even though App Review rejects test or placeholder features?

### Answers
1. No. A commit only saves the snapshot in your local repository on your Mac. `git push` is what uploads commits to the remote (`origin` on GitHub).
2. The write fails with "Operation not permitted" (Cocoa error 513). Dragging a file in grants access to **that file only**, not its folder, and the sandbox blocks writing anywhere the user has not granted. The fix is a folder grant through an open panel, remembered with a security-scoped bookmark.
3. Every spike file is wrapped in `#if DEBUG`, so the compiler leaves it out of Release builds entirely. We checked this: the Release binary contains zero spike strings.
