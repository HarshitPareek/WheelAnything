import Foundation
import Testing

@testable import WheelCore

struct ActionCatalogTests {
    struct ProEntitlements: Entitlements {
        var isProActive: Bool { true }
    }

    let free = ActionCatalog(entitlements: FreeTierEntitlements())
    let pro = ActionCatalog(entitlements: ProEntitlements())

    func file(_ format: InputFormat) -> DetectedFile {
        DetectedFile(url: URL(filePath: "/tmp/x"), format: format, extensionMatchesContent: true)
    }

    /// What a free-tier user is offered: Pro actions are locked.
    func freeOffer(_ action: WheelAction, pro: Bool = false) -> OfferedAction {
        OfferedAction(action: action, requiresPro: pro, isLocked: pro)
    }

    @Test func noFilesNoActions() {
        #expect(free.actions(for: []).isEmpty)
    }

    @Test func singlePNGHidesItsOwnFormat() {
        #expect(
            free.actions(for: [file(.png)]) == [
                freeOffer(.convertImage(to: .jpeg)), freeOffer(.convertImage(to: .heic)), freeOffer(.imagesToPDF),
                freeOffer(.removeBackground, pro: true), freeOffer(.extractText, pro: true),
            ])
    }

    @Test(arguments: [InputFormat.heic, .jpeg])
    func singleImageNeverOffersItsOwnFormat(format: InputFormat) {
        let actions = free.actions(for: [file(format)]).map(\.action)
        let ownFormat = ImageOutputFormat.allCases.first { $0.inputFormat == format }!
        #expect(!actions.contains(.convertImage(to: ownFormat)))
        #expect(actions.filter { if case .convertImage = $0 { true } else { false } }.count == 2)
    }

    // HEIF can be read but not written, so a HEIF file can still be converted to HEIC.
    @Test(arguments: [InputFormat.heif, .gif, .webP])
    func inputOnlyFormatsOfferAllThreeConversions(format: InputFormat) {
        let actions = free.actions(for: [file(format)]).map(\.action)
        for output in ImageOutputFormat.allCases {
            #expect(actions.contains(.convertImage(to: output)))
        }
    }

    @Test func singleImageConversionsAreFree() {
        let conversions = free.actions(for: [file(.png)]).filter {
            if case .convertImage = $0.action { true } else { false }
        }
        #expect(conversions.allSatisfy { !$0.requiresPro && !$0.isLocked })
    }

    @Test func severalImagesMakeConversionAProBatch() {
        let offered = free.actions(for: [file(.png), file(.jpeg)])
        #expect(offered.first == OfferedAction(action: .imagesToPDF, requiresPro: false, isLocked: false))
        let conversions = offered.filter { if case .convertImage = $0.action { true } else { false } }
        #expect(conversions.count == 3)
        #expect(conversions.allSatisfy { $0.requiresPro && $0.isLocked })
    }

    @Test func severalImagesOfOneFormatHideThatFormat() {
        let actions = free.actions(for: [file(.png), file(.png)]).map(\.action)
        #expect(!actions.contains(.convertImage(to: .png)))
        #expect(actions.contains(.convertImage(to: .jpeg)))
    }

    @Test func singlePDF() {
        #expect(free.actions(for: [file(.pdf)]) == [freeOffer(.pdfToImages), freeOffer(.extractText, pro: true)])
    }

    @Test func combinePDFsOnlyForTwoOrMore() {
        #expect(!free.actions(for: [file(.pdf)]).map(\.action).contains(.combinePDFs))
        #expect(
            free.actions(for: [file(.pdf), file(.pdf)]) == [
                freeOffer(.combinePDFs), freeOffer(.pdfToImages, pro: true), freeOffer(.extractText, pro: true),
            ])
    }

    @Test func imagesAndPDFsTogetherOnlyCombine() {
        #expect(free.actions(for: [file(.png), file(.pdf)]) == [freeOffer(.combineIntoPDF)])
    }

    @Test func proActionsLockedOnlyWithoutPro() {
        let files = [file(.png), file(.jpeg)]
        #expect(free.actions(for: files).contains { $0.isLocked })
        let unlocked = pro.actions(for: files)
        #expect(unlocked.allSatisfy { !$0.isLocked })
        #expect(unlocked.contains { $0.requiresPro })
    }
}
