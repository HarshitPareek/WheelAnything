import Foundation

/// A dropped file that can't be used, with the reason to show.
public struct RejectedFile: Equatable, Sendable {
    public let url: URL
    public let failure: DetectionFailure

    public init(url: URL, failure: DetectionFailure) {
        self.url = url
        self.failure = failure
    }
}

/// The files from one drop: the usable ones in drop order, and the rejected ones.
public struct FileSelection: Equatable, Sendable {
    public let files: [DetectedFile]
    public let rejected: [RejectedFile]

    public init(files: [DetectedFile], rejected: [RejectedFile]) {
        self.files = files
        self.rejected = rejected
    }

    /// Runs `detector` on every URL, keeping drop order.
    public init(detecting urls: [URL], with detector: any FileDetecting) {
        var files: [DetectedFile] = []
        var rejected: [RejectedFile] = []
        for url in urls {
            switch detector.detect(url) {
            case .success(let file): files.append(file)
            case .failure(let failure): rejected.append(RejectedFile(url: url, failure: failure))
            }
        }
        self.init(files: files, rejected: rejected)
    }
}

/// One action applied to a selection.
public struct Job: Equatable, Sendable {
    public let action: WheelAction
    public let files: [DetectedFile]
}

/// What the wheel is showing (PLAN.md §4, "States").
public enum WheelState: Equatable, Sendable {
    /// Only the pill is visible.
    case idle
    /// The wheel is open with no files.
    case expanded
    /// Files were dropped; the wheel shows the actions for them, or why none can be used.
    case filesSelected(FileSelection)
    case queued(Job)
    /// `progress` runs from 0 to 1.
    case converting(Job, progress: Double)
    case success(Job)
    case failure(Job, message: String)
    case cancelled(Job)

    /// A job is waiting or running. The wheel must stay open and keep the job.
    public var isJobRunning: Bool {
        switch self {
        case .queued, .converting: true
        default: false
        }
    }
}

/// Something that happened to the wheel.
public enum WheelEvent: Equatable, Sendable {
    case pillClicked
    case hotKeyPressed
    case escapePressed
    case clickedOutside
    case filesDropped(FileSelection)
    case actionChosen(WheelAction)
    case jobStarted
    case progressChanged(Double)
    case jobSucceeded
    case jobFailed(message: String)
    case cancelRequested
}

/// The wheel's interaction rules (PLAN.md §4) as one pure transition function.
///
/// Events that make no sense in the current state leave it unchanged, so the UI can send
/// events freely. While a job is queued or converting, only job events and Cancel apply:
/// closing the wheel or replacing the files mid-job is not allowed.
public struct WheelStateMachine: Sendable {
    public private(set) var state: WheelState = .idle
    private let catalog: ActionCatalog

    public init(catalog: ActionCatalog) {
        self.catalog = catalog
    }

    public mutating func handle(_ event: WheelEvent) {
        state = Self.next(after: state, on: event, catalog: catalog)
    }

    static func next(after state: WheelState, on event: WheelEvent, catalog: ActionCatalog) -> WheelState {
        if state.isJobRunning {
            return nextWhileRunning(state, on: event)
        }
        switch (state, event) {
        case (.idle, .pillClicked), (.idle, .hotKeyPressed):
            return .expanded
        case (_, .pillClicked), (_, .clickedOutside):
            return .idle
        case (.filesSelected, .escapePressed):
            return .expanded  // back one step
        case (_, .escapePressed):
            return .idle
        case (_, .filesDropped(let selection)):
            // Dropping only selects; it never starts a conversion (PLAN.md §4).
            return .filesSelected(selection)
        case (.filesSelected(let selection), .actionChosen(let action)):
            let offered = catalog.actions(for: selection.files).first { $0.action == action }
            guard let offered, !offered.isLocked else { return state }
            return .queued(Job(action: action, files: selection.files))
        default:
            return state
        }
    }

    private static func nextWhileRunning(_ state: WheelState, on event: WheelEvent) -> WheelState {
        switch (state, event) {
        case (.queued(let job), .jobStarted):
            return .converting(job, progress: 0)
        case (.converting(let job, _), .progressChanged(let progress)):
            return .converting(job, progress: min(max(progress, 0), 1))
        case (.converting(let job, _), .jobSucceeded):
            return .success(job)
        case (.queued(let job), .jobFailed(let message)), (.converting(let job, _), .jobFailed(let message)):
            return .failure(job, message: message)
        case (.queued(let job), .cancelRequested), (.converting(let job, _), .cancelRequested):
            return .cancelled(job)
        default:
            return state
        }
    }
}
