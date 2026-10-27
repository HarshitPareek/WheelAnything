#if DEBUG
import AppKit
import StoreKit

/// Spike 10: a local StoreKit test purchase of the Pro non-consumable.
/// Only works when Xcode runs the app with a StoreKit configuration file selected
/// in the scheme; otherwise the product list comes back empty.
enum StoreKitSpike {
    static let productID = "com.harshitpareek.WheelAnything.pro"

    @MainActor static func purchasePro() async {
        do {
            let products = try await Product.products(for: [productID])
            SpikeLog.line("STOREKIT products: \(products.map { "\($0.id) type=\($0.type) price=\($0.displayPrice)" })")
            guard let product = products.first else {
                SpikeLog.line("STOREKIT: product not found (is the StoreKit configuration selected in the scheme?)")
                return
            }
            // The purchase sheet belongs to the app; an agent app must be activated first.
            NSApp.activate()
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                SpikeLog.line("STOREKIT purchase verified: id=\(transaction.id) product=\(transaction.productID)")
                await transaction.finish()
            case .success(.unverified(_, let error)):
                SpikeLog.line("STOREKIT purchase UNVERIFIED: \(error)")
            case .userCancelled:
                SpikeLog.line("STOREKIT purchase cancelled by user")
            case .pending:
                SpikeLog.line("STOREKIT purchase pending")
            @unknown default:
                SpikeLog.line("STOREKIT purchase: unknown result")
            }
            for await entitlement in Transaction.currentEntitlements {
                SpikeLog.line("STOREKIT current entitlement: \(entitlement.unsafePayloadValue.productID)")
            }
        } catch {
            SpikeLog.line("STOREKIT error: \(error)")
        }
    }
}
#endif
