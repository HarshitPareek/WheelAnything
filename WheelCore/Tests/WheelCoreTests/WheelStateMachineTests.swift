import Foundation
import Testing

@testable import WheelCore

struct WheelStateMachineTests {
    struct ProEntitlements: Entitlements {
        var isProActive: Bool { true }
    }

    static let png = DetectedFile(url: URL(filePath: "/tmp/a.png"), format: .png, extensionMatchesContent: true)
    static let jpeg = DetectedFile(url: URL(filePath: "/tmp/b.jpg"), format: .jpeg, extensionMatchesContent: true)
    static let onePNG = FileSelection(files: [png], rejected: [])
    static let twoImages = FileSelection(files: [png, jpeg], rejected: [])
    static let job = Job(action: .convertImage(to: .jpeg), files: [png])

    static let notRunning: [WheelState] = [
        .idle, .expanded, .filesSelected(onePNG), .success(job), .failure(job, message: "x"), .cancelled(job),
    ]
    static let running: [WheelState] = [.queued(job), .converting(job, progress: 0.5)]

    func next(_ state: WheelState, _ event: WheelEvent, pro: Bool = false) -> WheelState {
        let catalog = ActionCatalog(entitlements: pro ? ProEntitlements() : FreeTierEntitlements())
        return WheelStateMachine.next(after: state, on: event, catalog: catalog)
    }

    // MARK: Opening and closing

    @Test func startsIdle() {
        #expect(WheelStateMachine(catalog: ActionCatalog(entitlements: FreeTierEntitlements())).state == .idle)
    }

    @Test func pillClickOpensAndCloses() {
        #expect(next(.idle, .pillClicked) == .expanded)
        #expect(next(.expanded, .pillClicked) == .idle)
    }

    @Test func hotKeyOnlyOpens() {
        #expect(next(.idle, .hotKeyPressed) == .expanded)
        #expect(next(.expanded, .hotKeyPressed) == .expanded)
        #expect(next(.filesSelected(Self.onePNG), .hotKeyPressed) == .filesSelected(Self.onePNG))
    }

    @Test(arguments: notRunning)
    func clickOutsideCloses(state: WheelState) {
        #expect(next(state, .clickedOutside) == .idle)
    }

    @Test(arguments: notRunning.dropFirst())
    func pillClickClosesAnyOpenState(state: WheelState) {
        #expect(next(state, .pillClicked) == .idle)
    }

    @Test func escapeGoesBackOneStepFromFiles() {
        #expect(next(.filesSelected(Self.onePNG), .escapePressed) == .expanded)
    }

    @Test(arguments: [WheelState.expanded, .success(job), .failure(job, message: "x"), .cancelled(job), .idle])
    func escapeClosesOtherStates(state: WheelState) {
        #expect(next(state, .escapePressed) == .idle)
    }

    // MARK: Dropping

    @Test(arguments: notRunning)
    func dropSelectsFilesAndNeverStartsAJob(state: WheelState) {
        let after = next(state, .filesDropped(Self.twoImages))
        #expect(after == .filesSelected(Self.twoImages))
        #expect(!after.isJobRunning)
    }

    @Test func dropWithOnlyRejectedFilesStillShowsThem() {
        let selection = FileSelection(
            files: [], rejected: [RejectedFile(url: URL(filePath: "/tmp/n.txt"), failure: .empty)])
        #expect(next(.idle, .filesDropped(selection)) == .filesSelected(selection))
    }

    // MARK: Choosing an action

    @Test func offeredFreeActionQueuesAJob() {
        #expect(next(.filesSelected(Self.onePNG), .actionChosen(.convertImage(to: .jpeg))) == .queued(Self.job))
    }

    @Test func lockedProActionDoesNotStart() {
        let state = WheelState.filesSelected(Self.twoImages)
        #expect(next(state, .actionChosen(.convertImage(to: .heic))) == state)
        #expect(next(state, .actionChosen(.removeBackground)) == state)
    }

    @Test func proActionStartsWithPro() {
        let state = WheelState.filesSelected(Self.twoImages)
        let after = next(state, .actionChosen(.convertImage(to: .heic)), pro: true)
        #expect(after == .queued(Job(action: .convertImage(to: .heic), files: [Self.png, Self.jpeg])))
    }

    @Test func actionNotOfferedForTheseFilesDoesNotStart() {
        let state = WheelState.filesSelected(Self.onePNG)
        #expect(next(state, .actionChosen(.combinePDFs), pro: true) == state)
        #expect(next(state, .actionChosen(.convertImage(to: .png)), pro: true) == state)
    }

    @Test(arguments: [WheelState.idle, .expanded])
    func actionWithoutFilesDoesNothing(state: WheelState) {
        #expect(next(state, .actionChosen(.imagesToPDF)) == state)
    }

    // MARK: Running jobs

    @Test func jobRunsToSuccess() {
        var state = next(.queued(Self.job), .jobStarted)
        #expect(state == .converting(Self.job, progress: 0))
        state = next(state, .progressChanged(0.4))
        #expect(state == .converting(Self.job, progress: 0.4))
        #expect(next(state, .jobSucceeded) == .success(Self.job))
    }

    @Test func progressIsClampedToZeroThroughOne() {
        let converting = WheelState.converting(Self.job, progress: 0.5)
        #expect(next(converting, .progressChanged(1.7)) == .converting(Self.job, progress: 1))
        #expect(next(converting, .progressChanged(-3)) == .converting(Self.job, progress: 0))
    }

    @Test(arguments: running)
    func runningJobCanFail(state: WheelState) {
        #expect(next(state, .jobFailed(message: "disk full")) == .failure(Self.job, message: "disk full"))
    }

    @Test(arguments: running)
    func runningJobCanBeCancelled(state: WheelState) {
        #expect(next(state, .cancelRequested) == .cancelled(Self.job))
    }

    @Test(arguments: running)
    func runningJobIgnoresClosingAndNewDrops(state: WheelState) {
        for event: WheelEvent in [
            .clickedOutside, .pillClicked, .escapePressed, .hotKeyPressed, .filesDropped(Self.onePNG),
        ] {
            #expect(next(state, event) == state)
        }
    }

    @Test(arguments: notRunning)
    func jobEventsOutsideAJobAreIgnored(state: WheelState) {
        for event: WheelEvent in [.jobStarted, .progressChanged(0.5), .jobSucceeded, .jobFailed(message: "x")] {
            #expect(next(state, event) == state)
        }
    }

    @Test func handleUpdatesState() {
        var machine = WheelStateMachine(catalog: ActionCatalog(entitlements: FreeTierEntitlements()))
        machine.handle(.filesDropped(Self.onePNG))
        machine.handle(.actionChosen(.imagesToPDF))
        #expect(machine.state == .queued(Job(action: .imagesToPDF, files: [Self.png])))
    }

    // MARK: Selection

    @Test func selectionKeepsDropOrderAndSeparatesRejected() {
        let fixtures = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
        let urls = ["red.jpg", "notes.txt", "red.png", "empty.png"].map { fixtures.appending(path: $0) }
        let selection = FileSelection(detecting: urls, with: FileDetector())
        #expect(selection.files.map(\.format) == [.jpeg, .png])
        #expect(selection.rejected.map(\.url.lastPathComponent) == ["notes.txt", "empty.png"])
    }
}
