import Testing

@testable import WheelCore

struct EntitlementsTests {
    @Test func freeTierIsNeverPro() {
        #expect(!FreeTierEntitlements().isProActive)
    }
}
