import AppKit

/// A borderless panel that floats above other apps without activating WheelAnything,
/// so the user's current app keeps its menus and active state (Stage 0 spike 1).
final class PillPanel: NSPanel {
    /// Called when the user presses Escape while the panel is key.
    var onEscape: (() -> Void)?

    init() {
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        // Status-bar level keeps the pill above normal and floating windows, including
        // full-screen apps (verified in Stage 0).
        level = .statusBar
        // canJoinAllSpaces: on every Space. fullScreenAuxiliary: allowed over a full-screen
        // app. stationary: Mission Control leaves it alone. ignoresCycle: not in ⌘` cycling.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // NSPanel hides whenever its app is inactive by default. An agent app (no Dock
        // icon) is almost never active, so the pill would vanish without this.
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
    }

    // Borderless windows refuse key status by default. Key status is needed to receive
    // Escape; with .nonactivatingPanel, becoming key still does not activate the app.
    override var canBecomeKey: Bool { true }

    // Escape arrives as cancelOperation(_:) through the responder chain.
    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
