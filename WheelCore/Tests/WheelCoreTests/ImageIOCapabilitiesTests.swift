import Testing
import UniformTypeIdentifiers
@testable import WheelCore

struct ImageIOCapabilitiesTests {
    // PNG is read and written by Image I/O on every macOS version we support,
    // so a missing PNG means the query itself is broken.
    @Test func currentSystemReadsAndWritesPNG() {
        let capabilities = ImageIOCapabilities.current()
        #expect(capabilities.canRead(.png))
        #expect(capabilities.canWrite(.png))
    }
}
