import Foundation
import Testing

@testable import WheelCore

struct FileDetectorTests {
    let detector = FileDetector()

    static func fixture(_ name: String) -> URL {
        Bundle.module.url(forResource: "Fixtures", withExtension: nil)!.appending(path: name)
    }

    @Test(arguments: [
        ("red.png", InputFormat.png),
        ("red.jpg", .jpeg),
        ("red.heic", .heic),
        ("one-page.pdf", .pdf),
    ])
    func detectsSupportedFormat(name: String, expected: InputFormat) throws {
        let file = try detector.detect(Self.fixture(name)).get()
        #expect(file.format == expected)
        #expect(file.extensionMatchesContent)
    }

    @Test func detectsPNGContentBehindJPEGName() throws {
        let file = try detector.detect(Self.fixture("png-named.jpg")).get()
        #expect(file.format == .png)
        #expect(!file.extensionMatchesContent)
    }

    @Test func rejectsPlainText() {
        let result = detector.detect(Self.fixture("notes.txt"))
        guard case .failure(.notSupported(let typeName)) = result else {
            Issue.record("Expected notSupported, got \(result)")
            return
        }
        #expect(typeName.localizedCaseInsensitiveContains("text"))
    }

    @Test func rejectsReadableImageFormatThatIsNotAV1Input() {
        let result = detector.detect(Self.fixture("red.tiff"))
        guard case .failure(.notSupported(let typeName)) = result else {
            Issue.record("Expected notSupported, got \(result)")
            return
        }
        #expect(typeName.localizedCaseInsensitiveContains("TIFF"))
    }

    @Test func rejectsEmptyFile() {
        #expect(detector.detect(Self.fixture("empty.png")) == .failure(.empty))
    }

    @Test func rejectsImageWithCutOffHeader() {
        #expect(detector.detect(Self.fixture("header-cut.png")) == .failure(.damaged(.png)))
    }

    @Test func rejectsDamagedPDF() {
        #expect(detector.detect(Self.fixture("damaged.pdf")) == .failure(.damaged(.pdf)))
    }

    @Test func rejectsFolder() {
        #expect(detector.detect(Self.fixture("")) == .failure(.isFolder))
    }

    @Test func reportsMissingFileAsUnreadable() {
        let result = detector.detect(Self.fixture("does-not-exist.png"))
        guard case .failure(.cannotRead) = result else {
            Issue.record("Expected cannotRead, got \(result)")
            return
        }
    }

    @Test func everyFailureHasAMessage() {
        let failures: [DetectionFailure] = [
            .isFolder, .cannotRead(reason: "x"), .empty, .damaged(.png), .notSupported(typeName: "TIFF image"),
        ]
        for failure in failures {
            #expect(!failure.message.isEmpty)
        }
    }
}
