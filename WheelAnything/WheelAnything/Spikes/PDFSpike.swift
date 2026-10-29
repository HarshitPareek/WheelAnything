#if DEBUG
    import AppKit
    import ImageIO
    import PDFKit

    /// Spike 7: build a 2-page PDF from two images, then render one page to PNG,
    /// and check both results by reopening them.
    enum PDFSpike {
        static func run() throws {
            let folder = try SpikeLog.outputFolder()
            let document = PDFDocument()
            for (index, color) in [NSColor.systemRed, .systemBlue].enumerated() {
                guard let page = PDFPage(image: solidImage(color, size: NSSize(width: 600, height: 400))) else {
                    throw SpikeFailure("PDFPage(image:) returned nil for page \(index + 1)")
                }
                document.insert(page, at: index)
            }
            let pdfURL = folder.appending(path: "two-pages.pdf")
            guard document.write(to: pdfURL) else { throw SpikeFailure("PDF write failed") }

            guard let reopened = PDFDocument(url: pdfURL), let firstPage = reopened.page(at: 0) else {
                throw SpikeFailure("Could not reopen \(pdfURL.path)")
            }
            SpikeLog.line("PDF \(pdfURL.path): reopened, pageCount=\(reopened.pageCount) (expected 2)")

            // Render at 2x (144 dpi) so the expected pixel size is easy to check.
            let scale: CGFloat = 2
            let bounds = firstPage.bounds(for: .mediaBox)
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)
            guard
                let context = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else {
                throw SpikeFailure("Could not create bitmap context")
            }
            context.setFillColor(.white)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)
            firstPage.draw(with: .mediaBox, to: context)
            guard let rendered = context.makeImage() else { throw SpikeFailure("Page render failed") }
            let pngURL = folder.appending(path: "two-pages-page1.png")
            try VisionSpike.writePNG(rendered, to: pngURL)

            guard let source = CGImageSourceCreateWithURL(pngURL as CFURL, nil),
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            else {
                throw SpikeFailure("Could not reopen \(pngURL.path)")
            }
            SpikeLog.line(
                "PNG \(pngURL.path): \(properties[kCGImagePropertyPixelWidth] ?? "?")x\(properties[kCGImagePropertyPixelHeight] ?? "?") (expected \(width)x\(height), page bounds \(bounds.size))"
            )
            if reopened.pageCount != 2 { throw SpikeFailure("Expected 2 pages") }
        }

        private static func solidImage(_ color: NSColor, size: NSSize) -> NSImage {
            NSImage(size: size, flipped: false) { rect in
                color.setFill()
                rect.fill()
                return true
            }
        }
    }
#endif
