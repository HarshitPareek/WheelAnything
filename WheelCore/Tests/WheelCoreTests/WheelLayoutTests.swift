import CoreGraphics
import Foundation
import Testing

@testable import WheelCore

struct WheelLayoutTests {
    @Test(arguments: 2...WheelLayout.maxSlices)
    func slicesSitOnTheLowerHalfLeftToRight(count: Int) {
        let centers = WheelLayout.sliceCenters(count: count, radius: 100)
        #expect(centers.count == count)
        for center in centers {
            #expect(center.y > 0)  // below the circle's center (SwiftUI y points down)
            #expect(abs(hypot(center.x, center.y) - 100) < 0.001)  // on the circle
        }
        #expect(centers.map(\.x) == centers.map(\.x).sorted())
    }

    @Test(arguments: 2...WheelLayout.maxSlices)
    func layoutIsSymmetric(count: Int) {
        let centers = WheelLayout.sliceCenters(count: count, radius: 100)
        for (left, right) in zip(centers, centers.reversed()) {
            #expect(abs(left.x + right.x) < 0.001)
            #expect(abs(left.y - right.y) < 0.001)
        }
    }

    @Test(arguments: 2...WheelLayout.maxSlices)
    func neighbouringSlicesNeverOverlap(count: Int) {
        let size: CGFloat = 64
        let gap: CGFloat = 8
        let radius = WheelLayout.radius(forCount: count, sliceSize: size, gap: gap, minimum: 90)
        let centers = WheelLayout.sliceCenters(count: count, radius: radius)
        for (a, b) in zip(centers, centers.dropFirst()) {
            #expect(hypot(b.x - a.x, b.y - a.y) >= size + gap - 0.001)
        }
    }

    @Test func noSlicesForZero() {
        #expect(WheelLayout.sliceCenters(count: 0, radius: 100).isEmpty)
    }

    @Test func v1ShowsOnlyImagesAndPDF() {
        #expect(WheelCategory.allCases == [.images, .pdf])
    }
}

@MainActor
struct WheelModelChoiceTests {
    static let png = DetectedFile(url: URL(filePath: "/tmp/a.png"), format: .png, extensionMatchesContent: true)

    func modelWithPNG() -> WheelModel {
        let model = WheelModel(catalog: ActionCatalog(entitlements: FreeTierEntitlements()), detector: FileDetector())
        model.send(.filesDropped(FileSelection(files: [Self.png], rejected: [])))
        return model
    }

    @Test func unbuiltActionShowsNoticeAndStartsNothing() {
        let model = modelWithPNG()
        let before = model.state
        model.choose(.convertImage(to: .jpeg))
        #expect(model.state == before)
        #expect(model.notice == "Convert to JPEG: not built yet.")
    }

    @Test func nextEventClearsTheNotice() {
        let model = modelWithPNG()
        model.choose(.imagesToPDF)
        model.send(.escapePressed)
        #expect(model.notice == nil)
    }

    // Tests run as a Debug build, where unbuilt actions are shown so they can be tried.
    @Test func debugBuildsShowEveryOfferedAction() {
        let model = modelWithPNG()
        #expect(model.visibleActions == model.offeredActions)
        #expect(!model.visibleActions.isEmpty)
    }

    @Test func notesListRejectionsMismatchesAndNotice() {
        let renamed = DetectedFile(
            url: URL(filePath: "/tmp/photo.jpg"), format: .png, extensionMatchesContent: false)
        let rejected = (1...5).map { RejectedFile(url: URL(filePath: "/tmp/\($0).txt"), failure: .empty) }
        let notes = WheelView.notes(
            for: FileSelection(files: [renamed], rejected: rejected), notice: "Convert to PNG: not built yet.")
        #expect(notes.count == 6)  // 3 rejections, "2 more", the mismatch, the notice
        #expect(notes[3] == "2 more files can't be used.")
        #expect(notes[4].hasPrefix("photo.jpg is really a "))
        #expect(notes[5] == "Convert to PNG: not built yet.")
    }
}
