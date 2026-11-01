import SwiftUI

/// The pill: click to open or close, drop files onto it. Stage 1 step 11 adds the
/// half-wheel of actions below it; until then the pill shows a one-line summary.
struct PillView: View {
    let model: WheelModel
    /// Reports the view's size so the panel can fit it exactly.
    let onSizeChange: (CGSize) -> Void
    @State private var isDropTargeted = false

    var body: some View {
        label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(minWidth: 44, minHeight: 32)
            .background(Capsule().fill(.black))
            .overlay(Capsule().strokeBorder(.white.opacity(isDropTargeted ? 0.9 : 0.2)))
            .contentShape(Capsule())
            .onTapGesture { model.send(.pillClicked) }
            .dropDestination(for: URL.self) { urls, _ in
                Task { await model.drop(urls) }
                return true
            } isTargeted: {
                isDropTargeted = $0
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(model.state.accessibilityDescription)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: {
                onSizeChange($0)
            }
    }

    @ViewBuilder private var label: some View {
        switch model.state {
        case .idle:
            Image(systemName: "circle.lefthalf.filled")
        case .expanded:
            Text("Drop files here")
        case .filesSelected(let selection):
            Text(summary(selection))
        default:
            Text(model.state.accessibilityDescription)
        }
    }

    private func summary(_ selection: FileSelection) -> String {
        if selection.files.isEmpty {
            return selection.rejected.first?.failure.message ?? "No files"
        }
        let actions = model.offeredActions.count
        let files = selection.files.count
        return "\(files) \(files == 1 ? "file" : "files") · \(actions) \(actions == 1 ? "action" : "actions")"
    }
}
