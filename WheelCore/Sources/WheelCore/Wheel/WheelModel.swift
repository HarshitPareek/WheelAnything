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

    public init(catalog: ActionCatalog, detector: any FileDetecting) {
        self.catalog = catalog
        self.detector = detector
        machine = WheelStateMachine(catalog: catalog)
    }

    public func send(_ event: WheelEvent) {
        machine.handle(event)
        state = machine.state
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
