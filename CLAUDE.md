# WheelAnything — Standing Rules for Claude Code

These rules apply to every task in this repository, in every session.
The full product plan is in `PLAN.md`. The current task is given separately, as a `TASK_STAGE_N.md` file.
If anything in a task message conflicts with these rules, stop and ask.

## 0. Who you are working with

The user is a **total beginner** in app development, DevOps, and backend work. They are building this project to learn those skills, not only to get a finished app. So:

- Explain in simple, plain language. Define every technical term the first time you use it.
- Before each meaningful change, say in 1–3 plain sentences what you will do and **why**.
- After each meaningful change, explain what the code does, as if teaching. Point to the exact files and lines.
- Do not dump large amounts of code without explanation.
- When a task is small and good practice (for example, a simple test, a small helper function, a git command), offer to let the user write it themselves. Then review their attempt honestly: say clearly what is wrong and why.
- At the end of every stage, add a section to `LEARNING_LOG.md`:
  - The 3–6 most important concepts from this stage, each explained in plain words.
  - Where each concept appears in this project's code.
  - 3 short quiz questions, with answers at the bottom of the section.
- If the user's idea or instruction is wrong, say so directly and explain why. Do not sugarcoat it.

## 1. Honesty and verification

- Use only real, documented Apple APIs. If you are not sure an API exists or behaves a certain way on macOS 14, check the SDK headers or documentation, or write a small test, before relying on it. Never invent APIs.
- Never fake functionality. Do not put a mock converter in the app, write placeholder output files, or report success when nothing was converted. Test doubles live only in test targets.
- A feature is "done" only when it compiles, its tests pass, and you have actually run it. Say exactly what you ran and what happened.
- In every report, separate these clearly:
  - implemented and tested
  - implemented but not tested
  - not implemented
  - unverified assumption
- Never claim compatibility (for example macOS 14 or Intel Macs) that you have not tested. List it as outstanding.

## 2. When to stop and ask the user

Stop and report instead of improvising when:

- A blocker needs something only the user can do: installing software, Apple Developer account or App Store Connect setup, granting system permissions, or steps in Xcode's graphical interface.
- `PLAN.md` contradicts itself, or contradicts what you find in the SDK or environment. Quote both and propose a fix.
- A requirement seems impossible with the chosen APIs or the App Sandbox.
- You would need a third-party dependency, entitlement, or network access not listed in `PLAN.md`.
- A choice would change user-visible behavior that `PLAN.md` does not specify.

## 3. Code standards

- Swift 6 language mode with strict concurrency checking. Fix concurrency warnings. Do not silence them with `@unchecked Sendable` or `nonisolated(unsafe)` unless a comment explains why it is safe.
- Deployment target: macOS 14.0. Guard any newer API with `if #available` and document the fallback.
- SwiftUI for views. AppKit only where SwiftUI cannot do the job (floating panel, global hot key, some drag-and-drop handling).
- Use `@Observable` (Observation framework) for app state.
- The UI never encodes files, writes files, or checks purchase status directly. It calls services.
- Services are defined by protocols and injected, so tests can substitute them.
- Comments explain *why*, especially for macOS window behavior, sandbox and file access, concurrency, and anything non-obvious. Add doc comments on public types and protocols.
- No telemetry, analytics, crash-reporting SDKs, or network calls. All file processing stays on the device. StoreKit, handled by the operating system, is the only allowed network use.
- Do not hand-edit `project.pbxproj`. Keep logic in the local Swift package, and when the Xcode project itself must change, give the user exact click-by-click steps.

## 4. Workflow for every meaningful change

1. State briefly what you are about to change and why.
2. Implement it, with comments.
3. Build.
4. Run the relevant tests.
5. Fix failures before moving on. Investigate root causes. Never delete or weaken a failing test without telling the user.
6. Commit to git with a clear message, one logical change per commit.
7. Update `DEVELOPMENT_STATUS.md`.

## 5. Git and DevOps rules

These apply once the GitHub repository and CI exist (see `PLAN.md` §8).

- Never commit directly to `main`. Do each piece of work on its own branch, named like `stage-2/image-engine` or `fix/output-naming`.
- Merge into `main` only through a pull request (PR). A PR is a request to add a branch's changes to `main`, which lets the changes be reviewed and checked first.
- A PR may be merged only when CI passes. CI (continuous integration) means GitHub automatically builds the app and runs the tests on every push.
- The user approves every merge. You may open PRs (with the `gh` command-line tool), but do not merge them unless the user says so.
- Never commit secrets: passwords, API keys, signing certificates, App Store Connect keys, `.env` files. Secrets go in GitHub Secrets or a local file listed in `.gitignore`.
- When you add or change anything DevOps-related (workflows, scripts, release steps), explain each line in plain language the first time.

## 6. Stage boundary report

At the end of every stage, report:

- Files created or changed.
- Features completed.
- Commands run and their actual results, including the key output lines.
- Tests passed and failed.
- Known limitations and unverified items.
- The recommended next step.
- Confirmation that the `LEARNING_LOG.md` section for this stage was written.

Then **stop and wait for the user's go-ahead** before starting the next stage.
