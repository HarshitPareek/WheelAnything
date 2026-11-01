import AppKit
import Observation
import SwiftUI

/// Shows the pill panel on the primary display and connects it to a `WheelModel`:
/// placement, resizing to fit its content, Escape, and clicks outside.
@MainActor
public final class PillPanelController: NSObject {
    private let model: WheelModel
    private let panel = PillPanel()
    private var clickOutsideMonitor: Any?

    public init(model: WheelModel) {
        self.model = model
        super.init()
        let content = PillView(model: model) { [weak self] size in self?.resize(to: size) }
        let hostingView = NSHostingView(rootView: content)
        panel.contentView = hostingView
        panel.setContentSize(hostingView.fittingSize)
        panel.onEscape = { [weak self] in self?.model.send(.escapePressed) }
    }

    public func show() {
        position()
        // orderFrontRegardless shows the panel even though the app is not active.
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // A global monitor only sees events sent to other apps, so every event it gets is
        // a click outside the pill. Mouse events need no Accessibility permission.
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            // Global monitor handlers run on the main thread.
            MainActor.assumeIsolated { self?.clickedOutside() }
        }
        observeState()
    }

    private func clickedOutside() {
        guard model.state != .idle else { return }
        model.send(.clickedOutside)
    }

    /// Keeps the panel key while the wheel is open so Escape reaches it. A non-activating
    /// panel becomes key without activating the app.
    private func observeState() {
        withObservationTracking {
            _ = model.state
        } onChange: { [weak self] in
            // onChange fires before the new value is stored, so read it on the next turn.
            Task { @MainActor in
                guard let self else { return }
                if self.model.state != .idle { self.panel.makeKey() }
                self.observeState()
            }
        }
    }

    /// Sizes the panel exactly to its content, so no invisible area blocks clicks to the
    /// apps underneath, and keeps its top edge fixed below the menu bar.
    private func resize(to size: CGSize) {
        guard size != panel.frame.size, size.width > 0, size.height > 0 else { return }
        panel.setContentSize(size)
        position()
    }

    @objc private func screenParametersChanged() {
        position()
    }

    /// The primary display (the one with the menu bar) is `NSScreen.screens.first`.
    private func position() {
        guard let screen = NSScreen.screens.first else { return }
        let origin = PanelPlacement.origin(
            for: panel.frame.size, screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
            safeAreaTop: screen.safeAreaInsets.top)
        panel.setFrameOrigin(origin)
    }
}
