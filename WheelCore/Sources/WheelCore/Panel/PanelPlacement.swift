import CoreGraphics

/// Where the pill panel sits: centered horizontally, just below the menu bar and the
/// camera notch (PLAN.md §4). Pure geometry, so it can be tested without a screen.
public enum PanelPlacement {
    /// Space between the menu bar (or notch) and the top of the panel, in points.
    public static let gap: CGFloat = 6

    /// The panel's bottom-left origin in screen coordinates (AppKit's origin is bottom-left).
    ///
    /// - Parameters:
    ///   - visibleFrame: the screen area without the menu bar and Dock.
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`, the notch height (0 without a notch).
    public static func origin(
        for size: CGSize, screenFrame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat
    ) -> CGPoint {
        // visibleFrame excludes a shown menu bar; the safe area covers the notch even when
        // the menu bar auto-hides. The lower of the two keeps the panel clear of both.
        let top = min(visibleFrame.maxY, screenFrame.maxY - safeAreaTop) - gap
        return CGPoint(x: (screenFrame.midX - size.width / 2).rounded(), y: top - size.height)
    }
}
