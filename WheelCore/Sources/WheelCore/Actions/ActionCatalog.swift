/// An image format WheelAnything v1 can write (PLAN.md §3.1; HEIF and WebP are input-only).
public enum ImageOutputFormat: String, Sendable, CaseIterable {
    case png, jpeg, heic

    var inputFormat: InputFormat {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        }
    }
}

/// Something the wheel can do with the selected files.
public enum WheelAction: Hashable, Sendable {
    case convertImage(to: ImageOutputFormat)
    /// One PDF page per image, in drop order.
    case imagesToPDF
    case removeBackground
    case extractText
    case pdfToImages
    case combinePDFs
    /// Images and PDFs together into one PDF.
    case combineIntoPDF
}

/// An action as the wheel offers it.
public struct OfferedAction: Equatable, Sendable {
    public let action: WheelAction
    /// Shown with a Pro badge.
    public let requiresPro: Bool
    /// True when the action requires Pro and the user does not have it.
    public let isLocked: Bool
}

/// Decides which actions to offer for a set of dropped files (TASK_STAGE_1.md, "Actions
/// offered after a drop"). The free tier covers single-file actions plus the two
/// "combine" actions; anything else on several files is a batch and requires Pro.
public struct ActionCatalog: Sendable {
    private let entitlements: any Entitlements

    public init(entitlements: any Entitlements) {
        self.entitlements = entitlements
    }

    /// Actions in the order the wheel shows them. Empty when there are no files.
    public func actions(for files: [DetectedFile]) -> [OfferedAction] {
        let images = files.filter { $0.format.isImage }
        let pdfs = files.filter { $0.format == .pdf }

        let offered: [(WheelAction, requiresPro: Bool)]
        switch (images.count, pdfs.count) {
        case (0, 0):
            offered = []
        case (_, 0):
            let isBatch = images.count > 1
            // Hide a format only when every file already has it: converting a mixed batch
            // still does work for the other files.
            let conversions = ImageOutputFormat.allCases
                .filter { output in !images.allSatisfy { $0.format == output.inputFormat } }
                .map { (WheelAction.convertImage(to: $0), requiresPro: isBatch) }
            let pdf = (WheelAction.imagesToPDF, requiresPro: false)
            let pro: [(WheelAction, requiresPro: Bool)] = [(.removeBackground, true), (.extractText, true)]
            // Free actions first, so a free user sees what they can use before the locked ones.
            offered = isBatch ? [pdf] + conversions + pro : conversions + [pdf] + pro
        case (0, 1):
            offered = [(.pdfToImages, false), (.extractText, true)]
        case (0, _):
            offered = [(.combinePDFs, false), (.pdfToImages, true), (.extractText, true)]
        default:
            offered = [(.combineIntoPDF, false)]
        }

        return offered.map { action, requiresPro in
            OfferedAction(action: action, requiresPro: requiresPro, isLocked: requiresPro && !entitlements.isProActive)
        }
    }
}
