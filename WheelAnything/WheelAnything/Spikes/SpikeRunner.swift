#if DEBUG
    import Foundation

    /// Runs one headless spike when the app is launched with `-spike <name>`, then exits.
    ///
    /// Usage from Terminal (the sandbox still applies when the binary is run directly):
    ///   WheelAnything.app/Contents/MacOS/WheelAnything -spike imageio
    /// Without `-spike`, this returns and the app starts normally with the interactive
    /// pill panel spike (see `SpikeAppDelegate`).
    enum SpikeRunner {
        static func runHeadlessSpikeIfRequested() {
            let args = CommandLine.arguments
            guard let flag = args.firstIndex(of: "-spike"), flag + 1 < args.count else { return }
            let name = args[flag + 1]
            let extra = Array(args.dropFirst(flag + 2))

            let spikes: [String: () throws -> Void] = [
                "baseline": {},  // Memory baseline for comparing the Vision spikes.
                "imageio": ImageIOSpike.run,
                "vision-mask": VisionSpike.runForegroundMask,
                "vision-ocr": VisionSpike.runOCR,
                "pdf": PDFSpike.run,
                "downloads": OutputSpike.writeToDownloads,
                "write-next-to": { try OutputSpike.writeNextTo(path: extra.first) },
                "hotkey-exclusive": { HotKeySpike.holdExclusive(seconds: Double(extra.first ?? "") ?? 0) },
            ]
            guard let spike = spikes[name] else {
                SpikeLog.line("Unknown spike '\(name)'. Known: \(spikes.keys.sorted().joined(separator: ", "))")
                exit(2)
            }
            SpikeLog.line("=== SPIKE \(name) ===")
            do {
                try spike()
                SpikeLog.line("=== SPIKE \(name) DONE ===")
                exit(0)
            } catch {
                SpikeLog.line("=== SPIKE \(name) FAILED: \(error) ===")
                exit(1)
            }
        }
    }
#endif
