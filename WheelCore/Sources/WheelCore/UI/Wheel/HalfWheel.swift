import SwiftUI

/// The half-wheel under the pill: 2–6 round slices spread over the lower half of a circle.
struct HalfWheel: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        var isPro = false
        var isLocked = false
        var accessibilityHint: String?
        let action: () -> Void
    }

    let items: [Item]
    private let sliceSize: CGFloat = 64

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let count = min(items.count, WheelLayout.maxSlices)
        // The wheel grows with the number of slices so neighbours never overlap.
        let radius = WheelLayout.radius(forCount: count, sliceSize: sliceSize, gap: 8, minimum: 90)
        let centers = WheelLayout.sliceCenters(count: count, radius: radius)
        let width = 2 * radius + sliceSize
        ZStack(alignment: .topLeading) {
            HalfDisc(topInset: sliceSize / 2)
                .fill(reduceTransparency ? Color.black : Color.black.opacity(0.82))
                .overlay(HalfDisc(topInset: sliceSize / 2).stroke(.white.opacity(contrast == .increased ? 0.8 : 0.15)))
            // Disc and slices share one center, half a slice below the top edge, so the
            // outermost slices stay inside the view.
            ForEach(Array(zip(items, centers)), id: \.0.id) { item, center in
                SliceButton(item: item, size: sliceSize)
                    .position(x: width / 2 + center.x, y: sliceSize / 2 + center.y)
            }
        }
        .frame(width: width, height: radius + sliceSize)
        // The strip above the shared center is empty; tuck it under the pill so it adds no
        // gap and no invisible area to the panel.
        .padding(.top, -sliceSize / 2)
        .environment(\.colorScheme, .dark)
    }
}

/// The lower half of a disc centered `topInset` below the middle of the view's top edge,
/// reaching the view's bottom edge.
struct HalfDisc: Shape {
    let topInset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.minY + topInset)
        path.move(to: center)
        path.addArc(
            center: center, radius: min(rect.width / 2, rect.height - topInset), startAngle: .degrees(0),
            endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct SliceButton: View {
    let item: HalfWheel.Item
    let size: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: item.action) {
            VStack(spacing: 4) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18))
                Text(item.title)
                    .font(.system(size: 10, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(6)
            .frame(width: size, height: size)
            .background(Circle().fill(.white.opacity(0.1)))
            .overlay(Circle().strokeBorder(.white.opacity(contrast == .increased ? 0.8 : 0.2)))
            .overlay(alignment: .topTrailing) {
                if item.isPro {
                    Image(systemName: item.isLocked ? "lock.fill" : "star.fill")
                        .font(.system(size: 10))
                        .padding(4)
                        .background(Circle().fill(.black))
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(item.title)
        .accessibilityLabel(item.isPro ? "\(item.title), Pro\(item.isLocked ? ", locked" : "")" : item.title)
        .accessibilityHint(item.accessibilityHint ?? "")
    }
}

extension WheelCategory {
    var systemImage: String {
        switch self {
        case .images: "photo"
        case .pdf: "doc"
        }
    }
}

extension WheelAction {
    var systemImage: String {
        switch self {
        case .convertImage: "arrow.triangle.2.circlepath"
        case .imagesToPDF: "doc.richtext"
        case .removeBackground: "person.crop.rectangle"
        case .extractText: "text.viewfinder"
        case .pdfToImages: "photo.on.rectangle"
        case .combinePDFs: "doc.on.doc"
        case .combineIntoPDF: "square.stack"
        }
    }
}
