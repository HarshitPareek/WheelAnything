# WheelAnything — Product & Implementation Plan (v2)

**Tagline:** Drop. Convert. Done.

`CLAUDE.md` holds the standing rules. Claude Code loads it automatically; those rules apply to everything below.

This project has two goals: ship a real Mac App Store app, and teach the user (a total beginner) app development, DevOps, and backend skills. Section 8 describes the two learning tracks.

---

## 1. What we are building

WheelAnything is an offline, on-device macOS file converter. A small black pill sits near the top center of the screen. When the user clicks it, presses the shortcut, or drags a file onto it, the pill expands into a half-wheel of actions.

Version 1 handles **Images** and **PDFs**, plus two on-device AI tools: **background removal** and **text extraction (OCR)**.

---

## 2. Decisions already made

| Topic | Decision |
|---|---|
| Distribution | Mac App Store, with the App Sandbox enabled. |
| Payments | StoreKit 2, one-time non-consumable purchase "WheelAnything Pro". The ₹299 / US$3.99 price is a hypothesis; confirm the tier in App Store Connect. |
| Free tier | Unlimited **single-file** basic actions: image format conversion, images → PDF, PDF → images, combine files into one PDF. No daily quota. |
| Pro tier | AI tools, batch processing (the same action on many files), saved presets, advanced quality and metadata controls. |
| Minimum macOS | 14.0 Sonoma. Required for Vision foreground masks and `@Observable`. |
| Architectures | Universal binary (arm64 + x86_64). Intel testing stays outstanding until it is actually done. |
| Tooling | Xcode 27.x (27.1 at Stage 0). An Xcode app project plus a local Swift package (`WheelCore`) that holds all logic except UI glue. |
| App presence | No Dock icon (`LSUIElement`). A menu bar icon with: Open Wheel, Settings…, Quit. |
| Default output | The user's Downloads folder, via the Downloads read-write sandbox entitlement. |
| Optional output | "Save next to original" after the user grants access to that folder once. The grant is remembered with a security-scoped bookmark. No app-scoped bookmark entitlement is needed (verified in Stage 0 on macOS 26; re-check on macOS 14). |
| Shortcut | User-configurable, with no hard-coded ⌥Space (it conflicts with Alfred, Raycast, ChatGPT, and typing a non-breaking space). First launch offers to set one. First launch suggests ⌃⌥⌘W. Registered with Carbon `RegisterEventHotKey`, which works in the sandbox without Accessibility permission (verified in Stage 0). macOS does not report when another app or the system already uses a combination, so the Shortcut setting warns when the user picks a well-known system shortcut and explains that other apps' shortcuts cannot be detected. |
| Wheel categories | v1 shows **Images** and **PDF** only. Unimplemented categories are **hidden**, not greyed out, because App Review rejects placeholder features. The wheel layout must support 2–6 slices so Video, Audio, Documents, and Archives can be added later. |
| Privacy | No network use, analytics, or telemetry. App Store privacy label: "Data Not Collected". |

---

## 3. Version 1 features

### 3.1 Images (free)

- Convert between PNG, JPEG, and HEIC. HEIF (`public.heif`) is accepted as input only: Image I/O reads it but cannot write it (Stage 0).
- Accept WebP as input if Image I/O reports it as a readable type at runtime.
- No WebP output in v1 unless Image I/O reports WebP as a *writable* type on the running OS. Do not add libwebp in v1. (Stage 0, macOS 26.6.2: WebP readable, not writable.)
- Quality slider for JPEG and HEIC.
- **Transparency:** preserve it where the output format supports it. When converting a transparent image to JPEG, show a warning and require an explicit background color choice (default white).
- **Metadata:** preserve it by default. Offer "remove all metadata" and "remove location only".
- **Orientation:** honor EXIF orientation correctly. Never silently rotate or resize.
- **Color profile:** preserve it.
- **Multi-frame inputs** (animated GIF, PNG, or HEIC): detect them, and warn when the conversion will keep only the first frame.

### 3.2 PDF (free), using PDFKit

- **Images → PDF:** one image per page, in the order the user dropped them, with reordering before conversion.
- **PDF → images:** every page or selected pages, to PNG or JPEG at a chosen resolution.
- **Combine PDFs:** merge several PDFs into one.

### 3.3 AI tools (Pro), on-device with Vision

- **Remove background:** image → PNG with a transparent background, using `VNGenerateForegroundInstanceMaskRequest` (macOS 14+).
  - If no subject is found, show a clear message. Do not output an unchanged image.
  - Verify this works on Intel, or mark it unverified.
- **Extract text (OCR):** image or PDF → `.txt` file, with an option to copy the text to the clipboard. Uses `VNRecognizeTextRequest`.
  - For PDFs, use the existing text layer where it exists, and OCR only the pages that have no text.
  - Recognition language: automatic, with a manual override in Settings.
- **Not in v1:** searchable-PDF output and audio/video transcription. These are planned for v1.1 or later.

### 3.4 Pro extras

- **Batch:** run one action on many files with a result for each file. A failure on one file does not stop the others.
- **Presets:** save format, quality, and metadata settings under a name.
- **Advanced controls:** the exact free/Pro split of controls is decided in Stage 5 and confirmed with the user.

---

## 4. Interface and interaction

### Pill and panel

- A persistent black pill, centered horizontally near the top of the screen.
- **Notched displays:** the pill must not sit behind the notch, because content there is invisible. Place it below the menu bar. Never claim to modify the notch.
- **Non-notched displays:** centered just below the menu bar.
- Shown on the primary display by default. Visible on all Spaces and over full-screen apps; verify both.
- Expands downward into a half-wheel.
- Look: dark translucent glass, subtle edge glow, white icons, fluid animation.
- Respect Reduce Motion, Reduce Transparency, and Increase Contrast.

### Interaction

- Clicking the pill opens or closes the wheel.
- Clicking outside closes the wheel, unless a job is running.
- Escape goes back one step, or closes the wheel.
- The shortcut opens the wheel.
- Dragging a file onto the pill detects its type and shows the relevant actions.
- **Dropping never starts a conversion automatically.** The user must choose an action.
- Unsupported or invalid files get a clear message explaining why.

### States

The UI distinguishes these states, each with its own visuals and VoiceOver description:

idle, expanded, file(s) selected, queued, converting, success, failure, cancelled.

### Pro actions and results

- Free users still see Pro actions, marked with a lock icon. Tapping one explains Pro and offers the purchase. This is a real feature behind a paywall, not a placeholder.
- After a job, show the output file with **Show in Finder** and **Open** buttons.

### Settings window

Sections: General, Output, Formats & Quality, Shortcut, Presets (Pro), Plan & About. Plan & About contains purchase, restore purchases, a privacy statement, and the version number.

Settings need full keyboard navigation, accessibility labels, and sensible focus order.

---

## 5. Architecture

All modules live in the `WheelCore` package unless marked as part of the app target.

- `App/` (app target): entry point, lifecycle, menu bar item.
- `Panel/`: `NSPanel` lifecycle, positioning, and reacting to screen changes.
- `UI/Wheel/`, `UI/Jobs/`, `UI/Settings/`, `UI/Paywall/`.
- `FileDetection/`: identifies file types by content (UTType plus Image I/O and PDFKit probing), not only by extension.
- `Formats/`: format definitions and runtime capability queries.
- `Conversion/`: job protocol, coordinator, progress, cancellation, batch runner.
- `Engines/Image/`, `Engines/PDF/`, `Engines/AI/` (Vision).
- `Output/`: destination resolution, folder access and bookmarks, temporary files, unique naming, atomic move.
- `Entitlements/`: StoreKit 2 and Pro state. This is the *only* place that decides whether Pro is active.
- `Preferences/`, `Presets/`, `Shortcuts/`.

The daily-quota `Usage/` module from plan v1 is **removed**, because there is no quota.

---

## 6. Safe output pipeline (every engine uses this)

1. Inspect the input and the requested output.
2. Validate the conversion pair, and check free disk space where practical.
3. Resolve the destination folder and confirm the app has write access to it.
4. Create a unique temporary output on the same volume as the destination.
5. Convert off the main thread.
6. Validate the temporary output: check that it reopens, and verify its format, dimensions or page count, and relevant metadata.
7. Move it into place under a unique name, such as `photo.jpg`, then `photo 2.jpg`. **Never overwrite** an existing file or the original.
8. On failure or cancellation, delete the temporary file. The source file is never modified on any path.

Guard against oversized inputs. Check pixel dimensions before fully decoding, and refuse or downsample with a clear warning above a documented limit.

---

## 7. Stages

Each stage ends with the report described in `CLAUDE.md` §6. Then stop and wait.

Steps marked **[DevOps]** belong to Track A (§8.1). They are part of the stage, not optional extras.

### Stage 0 — Setup and feasibility

Tasks are listed in `TASK_STAGE_0.md`.

- **[DevOps]** Local git repository, then a GitHub repository with the first push.

**Done when:** the app launches from Finder, the pill panel appears, every spike is marked pass, fail, or blocked with evidence, and the code is on GitHub.

### Stage 1 — UI shell with real file detection

- Pill, wheel, animations, states, menu bar item, and Settings skeleton.
- Drag-and-drop with real type detection.
- Actions that are not yet built show a clearly labelled "not built yet" message and produce no files. That message must never appear in release builds.
- **[DevOps]** First CI workflow (§8.1, step A2).
- **[DevOps]** Protect `main` and switch to the branch + pull request workflow (§8.1, step A3).

**Done when:** state-transition tests pass, drag-and-drop correctly identifies PNG, JPEG, HEIC, PDF, a renamed file with a wrong extension, and an unsupported file, and this stage's work was merged through a PR whose CI checks passed.

### Stage 2 — Image engine and output pipeline

- §3.1 image features plus the full §6 pipeline.
- Job UI: progress, cancel, result, and errors with Retry and Details.

**Done when:** integration tests convert small fixture files across all supported pairs and verify the outputs, and the transparency, orientation, metadata, and multi-frame cases are each tested.

### Stage 3 — PDF features

- §3.2 features.

**Done when:** tests verify page counts, page order, and rendered image dimensions.

### Stage 4 — AI tools

- §3.3 features, with cancellation, memory limits, and timing measurements.

**Done when:** fixture tests pass, covering a clear subject, no subject, a text image, a text PDF, and a scanned PDF. Report the measured time and memory.

### Stage 5 — Pro, batch, presets, persistence

- **StoreKit 2:**
  - Listen to `Transaction.updates` from app launch.
  - Check `Transaction.currentEntitlements`.
  - Restore with `AppStore.sync()`.
  - Handle pending purchases (Ask to Buy), cancelled purchases, offline launch, and unavailable StoreKit.
  - Test with a local StoreKit configuration file in Xcode.
- Lock icons and the paywall wired to the Entitlements service.
- Batch runner and presets.
- Versioned preferences with safe recovery from corrupted data.
- **[DevOps]** Versioning and release builds (§8.1, step A4).

**Done when:** tests cover the free, Pro, pending, revoked, and restored states, and a free user can never start a Pro action, even through a keyboard shortcut or preset.

### Stage 6 — Hardening

- Run the full test list in §9.
- Test with an external monitor, different display scaling, and notch and non-notch screens.
- Test with VoiceOver, keyboard-only use, and Reduce Motion.
- Large-image and memory-pressure tests.

### Stage 7 — Release

The user does steps 1–3; the agent provides checklists.

1. Apple Developer Program enrollment. **Start early**, because some developers in India report payment problems during enrollment.
2. Create the App Store Connect app record and the in-app purchase product.
3. Publish the privacy policy page. One is required even when the app collects no data. It lives on the companion website from Track B (§8.2).
4. Screenshots, description, and App Review notes explaining the pill, the shortcut, and that no data leaves the device.
5. Archive and upload through Xcode Organizer, then test through TestFlight for Mac. Do this manually the first time, so the user understands each step.
6. **[DevOps, stretch goal]** Automate signing and the TestFlight upload in CI (§8.1, step A5).
7. Finish the README (architecture, build and test commands, supported formats, limitations) and `DEVELOPMENT_STATUS.md`.

Do not call the app production-ready until these checks have actually passed.

---

## 8. Learning tracks

### 8.1 Track A — DevOps for the app (runs alongside Stages 0–7)

DevOps means the tools and habits for building, testing, and releasing software automatically and reliably. The agent explains every new tool and file in plain language the first time it appears.

**A1. Version control (Stage 0)**
- Initialize git, add a `.gitignore` for Swift/Xcode, and make the first commit.
- Create the GitHub repository. The user does this, following steps the agent gives. Public or private is an open decision (§10).
- Push the code. Explain the basic commands: `status`, `add`, `commit`, `push`, `pull`, `log`.

**A2. Continuous integration (Stage 1)**
- Add a GitHub Actions workflow at `.github/workflows/ci.yml` that runs on a GitHub-hosted macOS machine and:
  - builds the app with `xcodebuild`,
  - runs all tests,
  - checks code formatting with `swift format` (included with the Swift toolchain).
- Run it on pull requests and on pushes to `main` only, not on every push to every branch, to save CI minutes.
- **Cost note:** public repositories get GitHub-hosted runners free. In private repositories, macOS machines use the free monthly minutes 10× faster than Linux machines. Keep the workflow fast and check usage in GitHub settings.
- Break the build on purpose once (for example, a failing test), so the user sees CI catch it. Then fix it.

**A3. Branches and pull requests (Stage 1)**
- Protect `main` in GitHub settings: require a pull request, and require CI to pass. The user does this, following steps the agent gives.
- From now on, all work uses branches and pull requests, as described in `CLAUDE.md` §5.

**A4. Versioning and release builds (Stage 5)**
- Semantic versioning, explained: `MAJOR.MINOR.PATCH`, for example `1.0.0` → `1.0.1` for a bug fix.
- Tag releases in git, for example `v1.0.0`.
- Keep a `CHANGELOG.md`.
- Add a script that produces a Release build and checks it: architectures with `lipo -archs`, entitlements with `codesign -d --entitlements -`, and the deployment target.

**A5. Signing and upload automation (Stage 7, stretch goal)**
- Store signing certificates and an App Store Connect API key as GitHub Secrets. Never put them in the repository.
- Add a workflow, triggered by a version tag, that builds, signs, and uploads to TestFlight.
- Do this only after one successful manual upload.

### 8.2 Track B — Companion website and backend (starts after Stage 4)

The Mac app has no backend, on purpose: its promise is that no file ever leaves the user's Mac. To learn backend skills, build a separate companion website that the launch needs anyway. It holds the landing page, the waitlist, feedback, and the privacy policy.

**Hard rule:** the Mac app never talks to this server. The website is fully separate from the app.

**Repository:** a separate repository, `wheelanything-web`, with its own `CLAUDE.md` that copies the honesty, beginner-teaching, and git rules from this project.

**Stack (each piece explained to the user when introduced):**
- **Python + FastAPI** for the API. FastAPI is a Python framework for building web APIs; it is also widely used to deploy ML models, which helps an AI/ML portfolio.
- **Database:** SQLite while developing locally, then PostgreSQL in production. **Alembic** for migrations, which are versioned, step-by-step changes to the database structure.
- **pytest** for tests.
- **Docker** to package the server so it runs the same everywhere, and **Docker Compose** to run the API and database together locally.
- **GitHub Actions** CI on Linux machines, which are cheap.
- **Hosting:** a cloud host. Which one is an open decision (§10); compare current free tiers when Track B starts.

**Steps:**

| Step | Work | Done when |
|---|---|---|
| B1 | API endpoints: join the waitlist (email), send feedback (message + optional email), and a health check. Validate inputs. | pytest tests pass for valid input, invalid email, empty message, and duplicate waitlist sign-up. |
| B2 | Docker and Docker Compose setup. | `docker compose up` starts the API and database, and the tests pass inside the container. |
| B3 | CI: run tests and a linter on every pull request. | A failing test blocks the pull request. |
| B4 | Deploy to the chosen host. Custom domain, HTTPS, environment variables and secrets configured on the host. | The live site works over HTTPS. No secrets are in the repository. |
| B5 | CD (continuous deployment): merging to `main` deploys automatically. Add an uptime monitor and database backups, and test restoring a backup once. | A merged change goes live without manual steps, and a backup restore has been tested. |
| B6 | Security basics: rate limiting, spam protection on forms, CORS settings, no stack traces shown to visitors. | Each item is tested and documented. |
| B7 | Landing page and privacy policy. The policy must describe exactly what the *website* collects (waitlist emails, feedback) and state that the *app* collects nothing. | Pages are live, and the privacy policy URL is ready for App Store Connect. |

Track B must reach B7 before Stage 7 step 3.

---

## 9. Test list

**Unit tests:**
- Type detection, including misleading extensions.
- Capability reporting.
- Valid and invalid conversion pairs.
- Output naming and collisions.
- Temporary-file cleanup.
- Corrupted preferences.
- Entitlement states.

**Integration tests:**
- Every image pair.
- PDF operations.
- AI tools.
- Invalid, truncated, and unsupported files.
- Transparency, orientation, metadata, and multi-frame handling.
- Cancellation mid-job.
- Simulated write failure, such as a read-only destination.
- Batches where some files fail.
- Source file unchanged after every test (compare checksums).

Use small, deterministic fixture files committed to the repo. Do not rely only on looking at images by eye.

---

## 10. Open decisions (the user decides; the agent must not)

- ~~The default shortcut suggestion offered at first launch.~~ Decided: ⌃⌥⌘W.
- Whether free users get a few free AI uses to try the feature before buying.
- The final price tier.
- The app name: check the App Store and trademarks for "WheelAnything" before release.
- ~~**Public or private GitHub repository.**~~ Decided: public.
  - Public: free CI, and the code is visible to internship reviewers.
  - Private: protects the code of a paid app, but CI uses limited free minutes.
  - Decide before Stage 0 step A1.
- The hosting provider and domain name for the companion website (Track B).
