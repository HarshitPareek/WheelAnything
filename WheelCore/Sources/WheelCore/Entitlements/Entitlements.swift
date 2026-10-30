/// Answers whether the user has WheelAnything Pro.
///
/// This is the only place that decides Pro status (PLAN.md §5). Everything else, such as
/// which actions carry a Pro badge or may run, asks an injected `Entitlements` value,
/// so tests can substitute their own answer.
public protocol Entitlements: Sendable {
    var isProActive: Bool { get }
}

/// Stage 1 implementation: Pro can't be purchased yet, so every user is on the free tier.
/// Replaced by a StoreKit-backed implementation in Stage 5.
public struct FreeTierEntitlements: Entitlements {
    public init() {}

    public var isProActive: Bool { false }
}
