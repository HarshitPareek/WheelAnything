import Foundation
import Observation

/// The wheel's live state for the UI: wraps `WheelStateMachine` and turns dropped URLs
/// into a `FileSelection`. Views read `state` and send events; they never decide rules.
@MainActor
@Observable
public final class WheelModel {
    public private(set) var state: WheelState = .idle
    private var machine: WheelStateMachine
    private let catalog: ActionCatalog
    private let detector: any FileDetecting

    /// A short message about the last tap that could not run, such as an action that is not
    /// built yet. Cleared by the next event.
    public private(set) var notice: String?

    /// Actions whose engines exist. None in Stage 1; Stage 2 adds the image conversions.
    static let builtActions: Set<WheelAction> = []

    public convenience init(catalog: ActionCatalog, detector: any FileDetecting) {
        self.init(catalog: catalog, detector: detector, machine: WheelStateMachine(catalog: catalog))
    }

    /// Lets tests start from any state, such as a running job, without an engine.
    init(catalog: ActionCatalog, detector: any FileDetecting, machine: WheelStateMachine) {
        self.catalog = catalog
        self.detector = detector
        self.machine = machine
        state = machine.state
    }

    public func send(_ event: WheelEvent) {
        notice = nil
        machine.handle(event)
        state = machine.state
    }

    /// The actions the wheel shows. Release builds hide actions that are not built yet, so a
    /// "not built yet" message can never ship (TASK_STAGE_1.md).
    public var visibleActions: [OfferedAction] {
        #if DEBUG
            offeredActions
        #else
            offeredActions.filter { Self.builtActions.contains($0.action) }
        #endif
    }

    /// Starts an action the user tapped, or explains why it can't run yet.
    public func choose(_ action: WheelAction) {
        guard Self.builtActions.contains(action) else {
            // Release builds never show unbuilt actions, so this message exists only in Debug.
            #if DEBUG
                notice = "\(action.title): not built yet."
            #endif
            return
        }
        send(.actionChosen(action))
    }

    /// Detects the dropped files off the main thread (detection reads file headers),
    /// then selects them. Dropping never starts an action.
    public func drop(_ urls: [URL]) async {
        let detector = self.detector
        let selection = await Task.detached { FileSelection(detecting: urls, with: detector) }.value
        send(.filesDropped(selection))
    }

    /// The actions for the current selection; empty in every other state.
    public var offeredActions: [OfferedAction] {
        guard case .filesSelected(let selection) = state else { return [] }
        return catalog.actions(for: selection.files)
    }
}
