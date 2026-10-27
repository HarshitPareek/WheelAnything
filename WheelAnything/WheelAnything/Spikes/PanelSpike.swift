#if DEBUG
import AppKit
import Carbon.HIToolbox
import SwiftUI
import UniformTypeIdentifiers

/// Spikes 1, 2, 3 and 5c together: a floating pill panel that accepts dropped files,
/// toggles with a global hot key, and offers buttons for the folder-grant and StoreKit tests.
/// Started from `applicationDidFinishLaunching` so a plain Finder launch shows it.
final class SpikeAppDelegate: NSObject, NSApplicationDelegate {
    private let panelSpike = PanelSpikeController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelSpike.start()
    }
}

@Observable
final class PanelSpikeModel {
    var status = "Drop a file here"
    var expanded = false
    var isDropTargeted = false
    var lastDropped: URL?
}

/// A borderless panel that floats above other apps without making WheelAnything the
/// active app. That is what lets the user keep typing in their current app.
final class SpikePillPanel: NSPanel {
    init(content: NSView, size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        // Status-bar level keeps the pill above normal and floating windows, including
        // full-screen apps' windows.
        level = .statusBar
        // canJoinAllSpaces: same panel on every Space. fullScreenAuxiliary: allowed on top
        // of a full-screen app's Space. stationary: not moved by Mission Control.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // NSPanel hides itself whenever its app is inactive by default. An agent app is
        // almost never active, so the pill would be invisible without this.
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        contentView = content
    }

    // Borderless windows refuse key status by default; allow it so buttons and later
    // Escape handling work after a click.
    override var canBecomeKey: Bool { true }
}

final class PanelSpikeController: NSObject {
    private let model = PanelSpikeModel()
    private var panel: SpikePillPanel?
    private static let panelSize = NSSize(width: 380, height: 220)

    func start() {
        let view = PillSpikeView(
            model: model,
            onDrop: { [weak self] urls in self?.handleDrop(urls) },
            onGrantFolder: { _ = OutputSpike.grantFolder() },
            onRetryWrite: { [weak self] in OutputSpike.useSavedBookmark(nextTo: self?.model.lastDropped) },
            onPurchase: { Task { await StoreKitSpike.purchasePro() } })
        let panel = SpikePillPanel(content: NSHostingView(rootView: view), size: Self.panelSize)
        self.panel = panel
        position()
        // orderFrontRegardless shows the panel even though our app is not active.
        panel.orderFrontRegardless()
        SpikeLog.line("PANEL shown: level=\(panel.level.rawValue) collectionBehavior=\(panel.collectionBehavior.rawValue) frame=\(panel.frame)")

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        registerHotKeys()
        // Relaunch half of spike 5c: does a bookmark saved in an earlier run still work?
        OutputSpike.useSavedBookmark()
    }

    @objc private func screenParametersChanged() {
        SpikeLog.line("PANEL screen parameters changed; repositioning")
        position()
    }

    /// Centers the panel horizontally just below the menu bar of the primary display.
    /// On notched screens `safeAreaInsets.top` is the notch height, so staying below it
    /// keeps the pill out from behind the notch (PLAN.md §4).
    private func position() {
        guard let panel, let screen = NSScreen.screens.first else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame
        let safeTop = screen.safeAreaInsets.top
        // visibleFrame excludes the menu bar when it is shown; the safe area covers the
        // notch even when the menu bar auto-hides. Use whichever is lower.
        let topEdge = min(visible.maxY, frame.maxY - safeTop) - 6
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: topEdge - size.height))
        SpikeLog.line("""
            SCREEN \(screen.localizedName): frame=\(frame) visibleFrame=\(visible) \
            safeAreaInsets.top=\(safeTop) notch=\(safeTop > 0) \
            auxiliaryTopLeftArea=\(screen.auxiliaryTopLeftArea.map { "\($0)" } ?? "none") \
            auxiliaryTopRightArea=\(screen.auxiliaryTopRightArea.map { "\($0)" } ?? "none") \
            backingScale=\(screen.backingScaleFactor) screens=\(NSScreen.screens.count)
            """)
        SpikeLog.line("PANEL positioned at \(panel.frame)")
    }

    private func registerHotKeys() {
        HotKeySpike.onPress = { [weak self] id in
            guard let self else { return }
            SpikeLog.line("HOTKEY pressed id=\(id); frontmost app: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
            model.expanded.toggle()
            model.status = "Hot key \(id) pressed"
        }
        let control = cmdKey | optionKey | controlKey
        HotKeySpike.register(id: 1, keyCode: kVK_ANSI_W, modifiers: control, label: "⌃⌥⌘W")
        // Same combination again inside the same app; the header says this is not allowed.
        HotKeySpike.register(id: 2, keyCode: kVK_ANSI_W, modifiers: control, label: "⌃⌥⌘W (second time, same app)")
        // A combination the system already uses (Spotlight).
        HotKeySpike.register(id: 3, keyCode: kVK_Space, modifiers: cmdKey, label: "⌘Space (Spotlight's shortcut)")
    }

    private func handleDrop(_ urls: [URL]) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        SpikeLog.line("DROP received \(urls.count) item(s); frontmost app: \(frontmost); WheelAnything active: \(NSApp.isActive)")
        for url in urls {
            let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.identifier ?? "unknown"
            SpikeLog.line("DROP \(url.path) type=\(type) \(readProbe(url))")
            // Spike 5b: writing next to the dropped file without a folder grant.
            SpikeLog.line(OutputSpike.attemptWrite(nextTo: url))
        }
        model.lastDropped = urls.first
        model.status = "Dropped \(urls.first?.lastPathComponent ?? "nothing")"
    }

    /// Reads the first bytes to prove the drop also granted read access in the sandbox.
    private func readProbe(_ url: URL) -> String {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            return "read \(try handle.read(upToCount: 16)?.count ?? 0) bytes OK"
        } catch {
            return "read FAILED \(error)"
        }
    }
}

struct PillSpikeView: View {
    let model: PanelSpikeModel
    let onDrop: ([URL]) -> Void
    let onGrantFolder: () -> Void
    let onRetryWrite: () -> Void
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(model.status)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(Capsule().fill(.black))
                .overlay(Capsule().strokeBorder(.white.opacity(model.isDropTargeted ? 0.9 : 0.25)))
                .contentShape(Capsule())
                .onTapGesture { model.expanded.toggle() }
                .dropDestination(for: URL.self) { urls, _ in
                    onDrop(urls)
                    return true
                } isTargeted: { model.isDropTargeted = $0 }

            if model.expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stage 0 spike controls").font(.caption).foregroundStyle(.secondary)
                    Button("Grant folder access…", action: onGrantFolder)
                    Button("Retry write next to last drop (via bookmark)", action: onRetryWrite)
                    Button("Test purchase (StoreKit)", action: onPurchase)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.85)))
                .environment(\.colorScheme, .dark)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
#endif
