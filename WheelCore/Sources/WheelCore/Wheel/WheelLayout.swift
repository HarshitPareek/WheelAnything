import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// Where the slices of the half-wheel go. Pure geometry, so it can be tested without a screen.
public enum WheelLayout {
    /// PLAN.md §2: the layout must hold 2–6 slices so later categories fit.
    public static let maxSlices = 6

    /// The smallest radius at which `count` round slices of `sliceSize` keep `gap` between
    /// neighbours. Neighbouring centers are 2·r·sin(90°/count) apart on the half circle.
    public static func radius(forCount count: Int, sliceSize: CGFloat, gap: CGFloat, minimum: CGFloat) -> CGFloat {
        guard count > 1 else { return minimum }
        let needed = (sliceSize + gap) / (2 * CGFloat(sin(Double.pi / (2 * Double(count)))))
        return max(minimum, needed.rounded(.up))
    }

    /// Slice centers relative to the circle's center, left to right, spread evenly over the
    /// lower half of the circle. SwiftUI's y axis points down, so "below" means y > 0.
    public static func sliceCenters(count: Int, radius: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            // From the left (180°) to the right (0°), each slice in the middle of its sector.
            let angle = Double.pi - (Double(index) + 0.5) * Double.pi / Double(count)
            return CGPoint(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
        }
    }
}

/// What the wheel offers before any file is chosen. v1 has only Images and PDF; categories
/// that are not built are left out entirely, not shown greyed out (PLAN.md §2).
public enum WheelCategory: String, CaseIterable, Sendable {
    case images, pdf

    public var title: String {
        switch self {
        case .images: "Images"
        case .pdf: "PDF"
        }
    }

    /// File types the file chooser shows for this category.
    public var contentTypes: [UTType] {
        switch self {
        case .images: [.image]
        case .pdf: [.pdf]
        }
    }
}
