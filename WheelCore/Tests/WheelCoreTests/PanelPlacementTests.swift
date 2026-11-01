import CoreGraphics
import Testing

@testable import WheelCore

struct PanelPlacementTests {
    let pill = CGSize(width: 120, height: 32)

    // Numbers measured on the notched MacBook Air in Stage 0: the notch is 32 pt tall and
    // the visible frame ends at 923, so the panel's top sits at 923 - 6 = 917.
    @Test func notchedBuiltInDisplay() {
        let origin = PanelPlacement.origin(
            for: pill, screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 0, y: 72, width: 1470, height: 851), safeAreaTop: 32)
        #expect(origin == CGPoint(x: 675, y: 917 - 32))
    }

    @Test func nonNotchedDisplayWithMenuBar() {
        let origin = PanelPlacement.origin(
            for: pill, screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055), safeAreaTop: 0)
        #expect(origin == CGPoint(x: 900, y: 1055 - 6 - 32))
    }

    // With an auto-hidden menu bar the visible frame reaches the top; the notch still must be avoided.
    @Test func notchedDisplayWithHiddenMenuBarStaysBelowNotch() {
        let origin = PanelPlacement.origin(
            for: pill, screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 0, y: 0, width: 1470, height: 956), safeAreaTop: 32)
        #expect(origin.y + pill.height == CGFloat(956 - 32 - 6))
    }

    @Test func displayWithOffsetOrigin() {
        let origin = PanelPlacement.origin(
            for: pill, screenFrame: CGRect(x: -1920, y: 200, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1920, y: 200, width: 1920, height: 1055), safeAreaTop: 0)
        #expect(origin.x == CGFloat(-1920 + 960 - 60))
        #expect(origin.y == CGFloat(200 + 1055 - 6 - 32))
    }
}
