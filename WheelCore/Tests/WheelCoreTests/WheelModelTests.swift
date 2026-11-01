import Foundation
import Testing

@testable import WheelCore

@MainActor
struct WheelModelTests {
    static let job = Job(action: .extractText, files: [])

    func makeModel() -> WheelModel {
        WheelModel(catalog: ActionCatalog(entitlements: FreeTierEntitlements()), detector: FileDetector())
    }

    @Test func dropDetectsFilesAndSelectsWithoutStartingAJob() async {
        let fixtures = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
        let model = makeModel()
        await model.drop([fixtures.appending(path: "red.png"), fixtures.appending(path: "notes.txt")])
        guard case .filesSelected(let selection) = model.state else {
            Issue.record("Expected filesSelected, got \(model.state)")
            return
        }
        #expect(selection.files.map(\.format) == [.png])
        #expect(selection.rejected.count == 1)
        #expect(!model.offeredActions.isEmpty)
        #expect(!model.state.isJobRunning)
    }

    @Test func offeredActionsEmptyWithoutFiles() {
        let model = makeModel()
        model.send(.openRequested)
        #expect(model.state == .expanded)
        #expect(model.offeredActions.isEmpty)
    }

    @Test func everyStateHasItsOwnAccessibilityDescription() {
        let selection = FileSelection(files: [], rejected: [RejectedFile(url: URL(filePath: "/x"), failure: .empty)])
        let states: [WheelState] = [
            .idle, .expanded, .filesSelected(selection), .queued(Self.job), .converting(Self.job, progress: 0.25),
            .success(Self.job), .failure(Self.job, message: "Disk full."), .cancelled(Self.job),
        ]
        let descriptions = states.map(\.accessibilityDescription)
        #expect(descriptions.allSatisfy { !$0.isEmpty })
        #expect(Set(descriptions).count == states.count)
        #expect(WheelState.converting(Self.job, progress: 0.25).accessibilityDescription.contains("25 percent"))
    }
}
