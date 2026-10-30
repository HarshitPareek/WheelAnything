#if DEBUG
    import AppKit
    import CoreImage
    import ImageIO
    import UniformTypeIdentifiers
    import Vision

    /// Spike 6: background removal and OCR with Vision, timed.
    /// Peak memory is measured from outside with `/usr/bin/time -l`, compared with the
    /// `baseline` spike, so this code does not need to read process statistics itself.
    enum VisionSpike {
        static let sampleImage = URL(filePath: "/Library/User Pictures/Animals/Parrot.heic")

        static func runForegroundMask() throws {
            SpikeLog.line("Input: \(sampleImage.path)")
            let handler = VNImageRequestHandler(url: sampleImage)
            let request = VNGenerateForegroundInstanceMaskRequest()
            try SpikeLog.timed("Foreground mask request") { try handler.perform([request]) }
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                throw SpikeFailure("No foreground subject found")
            }
            SpikeLog.line("Instances found: \(observation.allInstances.count)")
            let buffer = try SpikeLog.timed("Generate masked image") {
                try observation.generateMaskedImage(
                    ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false)
            }
            let image = CIImage(cvPixelBuffer: buffer)
            guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
                throw SpikeFailure("Could not convert mask result to CGImage")
            }
            let output = try SpikeLog.outputFolder().appending(path: "parrot-no-background.png")
            try writePNG(cgImage, to: output)
            SpikeLog.line(
                "Saved \(output.path) (\(cgImage.width)x\(cgImage.height), alpha=\(cgImage.alphaInfo.rawValue))")
        }

        static func runOCR() throws {
            let expected = ["WheelAnything OCR test", "Drop. Convert. Done. 2026"]
            let image = try renderText(expected)
            let input = try SpikeLog.outputFolder().appending(path: "ocr-input.png")
            try writePNG(image, to: input)
            SpikeLog.line("Rendered test image \(input.path)")

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            try SpikeLog.timed("OCR request") { try VNImageRequestHandler(cgImage: image).perform([request]) }
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first }
            for line in lines {
                SpikeLog.line("Recognized: \"\(line.string)\" confidence=\(line.confidence)")
            }
            let matches = lines.map(\.string) == expected
            SpikeLog.line("OCR matches expected text exactly: \(matches)")
            if !matches { throw SpikeFailure("OCR text differs from the rendered text") }
        }

        /// Draws black text on white into a bitmap so the OCR input is known exactly.
        private static func renderText(_ lines: [String]) throws -> CGImage {
            let size = NSSize(width: 1200, height: 300)
            guard
                let context = CGContext(
                    data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else {
                throw SpikeFailure("Could not create bitmap context")
            }
            context.setFillColor(.white)
            context.fill(CGRect(origin: .zero, size: size))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black,
            ]
            for (index, line) in lines.enumerated() {
                NSAttributedString(string: line, attributes: attributes)
                    .draw(at: NSPoint(x: 40, y: size.height - 120 - CGFloat(index) * 110))
            }
            NSGraphicsContext.restoreGraphicsState()
            guard let image = context.makeImage() else { throw SpikeFailure("Could not render text image") }
            return image
        }

        static func writePNG(_ image: CGImage, to url: URL) throws {
            guard
                let destination = CGImageDestinationCreateWithURL(
                    url as CFURL, UTType.png.identifier as CFString, 1, nil)
            else {
                throw SpikeFailure("Could not create PNG destination at \(url.path)")
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw SpikeFailure("PNG write failed: \(url.path)") }
        }
    }
#endif
