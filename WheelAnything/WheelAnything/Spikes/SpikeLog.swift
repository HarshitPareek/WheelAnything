#if DEBUG
// Stage 0 feasibility spikes. Debug builds only: `#if DEBUG` removes this whole
// folder from Release builds, so none of it can ship to the App Store.
import Foundation
import os

/// Writes spike results to stdout (for Terminal runs) and to the unified system log
/// (for Finder launches, read back with `log show --predicate 'category == "spike"'`).
enum SpikeLog {
    private static let logger = Logger(subsystem: "com.harshitpareek.WheelAnything", category: "spike")

    static func line(_ message: String) {
        print(message)
        // `.public` because these are diagnostic paths and results we want to read back;
        // the default would redact them as private.
        logger.notice("\(message, privacy: .public)")
    }

    /// Where spikes put files they produce. Downloads is one of the two places the
    /// sandbox lets us write without asking (PLAN.md §2).
    static func outputFolder() throws -> URL {
        let downloads = try FileManager.default.url(
            for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let folder = downloads.appending(path: "WheelAnything Spike Output", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Runs `body` and logs how long it took.
    static func timed<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
        let start = ContinuousClock.now
        let result = try body()
        line("\(label) took \(start.duration(to: .now).formatted(.units(allowed: [.milliseconds])))")
        return result
    }
}

struct SpikeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
#endif
