import SwiftUI

/// Everything inside the pill panel: the pill, and below it whatever the wheel's state needs
/// (categories, actions, job progress or a result).
struct WheelView: View {
    let model: WheelModel
    /// Opens the file chooser for a category; the controller owns AppKit's NSOpenPanel.
    let onChooseFiles: (WheelCategory) -> Void
    /// Reports the view's size so the panel can fit it exactly.
    let onSizeChange: (CGSize) -> Void

    @State private var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            PillView(state: model.state, isDropTargeted: isDropTargeted) { model.send(.pillClicked) }
            if model.state != .idle {
                content
                    .padding(.horizontal, 4)
                    .transition(
                        reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .top).combined(with: .opacity))
            }
        }
        .padding(.bottom, model.state == .idle ? 0 : 8)
        // Reduce Motion: a plain fade instead of the spring (PLAN.md §4).
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.35), value: model.state)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.drop(urls) }
            return true
        } isTargeted: {
            isDropTargeted = $0
        }
        .fixedSize()
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            onSizeChange($0)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .expanded:
            HalfWheel(
                items: WheelCategory.allCases.map { category in
                    HalfWheel.Item(
                        id: category.rawValue, title: category.title, systemImage: category.systemImage,
                        accessibilityHint: "Choose \(category.title.lowercased()) files"
                    ) { onChooseFiles(category) }
                })
        case .filesSelected(let selection):
            filesSelected(selection)
        case .queued(let job):
            JobStatusView(title: job.action.title, detail: "Waiting to start", progress: nil) {
                model.send(.cancelRequested)
            }
        case .converting(let job, let progress):
            JobStatusView(title: job.action.title, detail: nil, progress: progress) {
                model.send(.cancelRequested)
            }
        case .success(let job):
            ResultView(systemImage: "checkmark.circle.fill", title: "\(job.action.title) finished", detail: nil)
        case .failure(let job, let message):
            ResultView(systemImage: "xmark.octagon.fill", title: "\(job.action.title) failed", detail: message)
        case .cancelled(let job):
            ResultView(systemImage: "stop.circle.fill", title: "\(job.action.title) cancelled", detail: nil)
        }
    }

    @ViewBuilder private func filesSelected(_ selection: FileSelection) -> some View {
        VStack(spacing: 8) {
            let actions = model.visibleActions
            if !actions.isEmpty {
                HalfWheel(
                    items: actions.map { offered in
                        HalfWheel.Item(
                            id: "\(offered.action)", title: offered.action.title,
                            systemImage: offered.action.systemImage, isPro: offered.requiresPro,
                            isLocked: offered.isLocked
                        ) { model.choose(offered.action) }
                    })
            }
            ForEach(Self.notes(for: selection, notice: model.notice), id: \.self) { note in
                NoteView(text: note)
            }
        }
    }

    /// Short lines under the wheel: why files were left out, names that don't match their
    /// content, and the last notice. At most three rejection lines, then a count.
    static func notes(for selection: FileSelection, notice: String?) -> [String] {
        var notes: [String] = []
        for rejected in selection.rejected.prefix(3) {
            notes.append("\(rejected.url.lastPathComponent): \(rejected.failure.message)")
        }
        if selection.rejected.count > 3 {
            notes.append("\(selection.rejected.count - 3) more files can't be used.")
        }
        for file in selection.files where !file.extensionMatchesContent {
            notes.append(
                "\(file.url.lastPathComponent) is really a \(file.format.utType.localizedDescription ?? "different type")."
            )
        }
        if let notice { notes.append(notice) }
        return notes
    }
}

/// The black pill at the top. Click to open or close the wheel.
struct PillView: View {
    let state: WheelState
    let isDropTargeted: Bool
    let onClick: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: onClick) {
            label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minWidth: 44, minHeight: 32)
                .background(Capsule().fill(.black))
                .overlay(Capsule().strokeBorder(.white.opacity(borderOpacity)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.accessibilityDescription)
    }

    // Increase Contrast and an active drop both get a clearly visible edge.
    private var borderOpacity: Double {
        isDropTargeted || contrast == .increased ? 0.9 : 0.2
    }

    @ViewBuilder private var label: some View {
        switch state {
        case .idle:
            Image(systemName: "circle.lefthalf.filled")
        case .expanded:
            Text("Drop files or choose a category")
        case .filesSelected(let selection):
            Text(Self.summary(selection))
        case .queued, .converting:
            Text("Working…")
        case .success:
            Text("Done")
        case .failure:
            Text("Failed")
        case .cancelled:
            Text("Cancelled")
        }
    }

    static func summary(_ selection: FileSelection) -> String {
        let count = selection.files.count
        if count == 0 { return selection.rejected.count == 1 ? "Can't use this file" : "Can't use these files" }
        return "\(count) \(count == 1 ? "file" : "files")"
    }
}

/// A queued or running job: title, progress and Cancel.
struct JobStatusView: View {
    let title: String
    let detail: String?
    /// nil shows an indeterminate spinner.
    let progress: Double?
    let onCancel: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                if let progress {
                    ProgressView(value: progress)
                        .accessibilityLabel("\(title) progress")
                } else {
                    ProgressView().controlSize(.small)
                }
                HStack {
                    if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Cancel", action: onCancel)
                }
            }
            .frame(width: 240)
        }
    }
}

/// A finished, failed or cancelled job. Stage 2 adds Show in Finder, Open and Retry here.
struct ResultView: View {
    let systemImage: String
    let title: String
    let detail: String?

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage).font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .frame(width: 240, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One line of information under the wheel.
struct NoteView: View {
    let text: String

    var body: some View {
        GlassCard {
            Text(text)
                .font(.caption)
                .frame(maxWidth: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The dark translucent "glass" behind wheel content. Reduce Transparency makes it solid
/// black; Increase Contrast strengthens its edge (PLAN.md §4).
struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content
            .padding(12)
            .foregroundStyle(.white)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(reduceTransparency ? AnyShapeStyle(Color.black) : AnyShapeStyle(Color.black.opacity(0.82)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(contrast == .increased ? 0.8 : 0.15))
            }
            .environment(\.colorScheme, .dark)
    }
}
