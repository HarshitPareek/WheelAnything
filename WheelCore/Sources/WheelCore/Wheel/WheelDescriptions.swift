extension ImageOutputFormat {
    public var displayName: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .heic: "HEIC"
        }
    }
}

extension WheelAction {
    /// The action's name as the wheel shows it.
    public var title: String {
        switch self {
        case .convertImage(let format): "Convert to \(format.displayName)"
        case .imagesToPDF: "Images to PDF"
        case .removeBackground: "Remove Background"
        case .extractText: "Extract Text"
        case .pdfToImages: "PDF to Images"
        case .combinePDFs: "Combine PDFs"
        case .combineIntoPDF: "Combine into One PDF"
        }
    }
}

extension WheelState {
    /// What VoiceOver says about the wheel in this state (PLAN.md §4: every state has its own description).
    public var accessibilityDescription: String {
        switch self {
        case .idle:
            "WheelAnything. Click to open, or drop files here."
        case .expanded:
            "WheelAnything is open. Drop files to see what you can do with them."
        case .filesSelected(let selection):
            Self.describe(selection)
        case .queued(let job):
            "\(job.action.title) is waiting to start."
        case .converting(let job, let progress):
            "\(job.action.title): \(Int((progress * 100).rounded())) percent done."
        case .success(let job):
            "\(job.action.title) finished."
        case .failure(let job, let message):
            "\(job.action.title) failed. \(message)"
        case .cancelled(let job):
            "\(job.action.title) was cancelled."
        }
    }

    private static func describe(_ selection: FileSelection) -> String {
        let usable = selection.files.count
        let rejected = selection.rejected.count
        switch (usable, rejected) {
        case (0, _):
            return selection.rejected.count == 1
                ? "This file can't be used. \(selection.rejected[0].failure.message)"
                : "None of the \(rejected) files can be used."
        case (_, 0):
            return "\(usable) \(usable == 1 ? "file" : "files") selected. Choose an action."
        default:
            return "\(usable) \(usable == 1 ? "file" : "files") selected, \(rejected) can't be used. Choose an action."
        }
    }
}
