import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// A file format WheelAnything v1 accepts as input (PLAN.md §3).
public enum InputFormat: String, Sendable, CaseIterable {
    case png, jpeg, heic, heif, gif, webP, pdf

    public var utType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .heif: .heif
        case .gif: .gif
        case .webP: .webP
        case .pdf: .pdf
        }
    }

    public var isImage: Bool { self != .pdf }

    /// Maps the type Image I/O reports for an image's bytes. Other formats Image I/O can
    /// read (TIFF, BMP, RAW, …) return nil: they are not supported in v1.
    init?(imageIOType identifier: String) {
        switch identifier {
        case UTType.png.identifier: self = .png
        case UTType.jpeg.identifier: self = .jpeg
        // "public.heics" is a HEIC image sequence; multi-frame handling is Stage 2's job.
        case UTType.heic.identifier, "public.heics": self = .heic
        case UTType.heif.identifier: self = .heif
        case UTType.gif.identifier: self = .gif
        case UTType.webP.identifier: self = .webP
        default: return nil
        }
    }
}

/// A dropped file whose content is a supported format.
public struct DetectedFile: Sendable, Equatable {
    public let url: URL
    /// What the file's bytes are, regardless of its name.
    public let format: InputFormat
    /// False when the extension names a different type than the content, e.g. a PNG named `photo.jpg`.
    public let extensionMatchesContent: Bool
}

/// Why a dropped file can't be used.
public enum DetectionFailure: Error, Sendable, Equatable {
    case isFolder
    case cannotRead(reason: String)
    case empty
    /// The content starts like `format` but its header can't be parsed.
    case damaged(InputFormat)
    /// Readable, but not an image or PDF WheelAnything converts. `typeName` is the
    /// system's description, such as "TIFF image" or "plain text document".
    case notSupported(typeName: String)

    /// A sentence to show the user.
    public var message: String {
        switch self {
        case .isFolder: "Folders can't be converted. Drop the files inside it instead."
        case .cannotRead(let reason): "The file couldn't be read: \(reason)"
        case .empty: "The file is empty."
        case .damaged(let format):
            "The file looks like a \(format.utType.localizedDescription ?? "supported file") but is damaged."
        case .notSupported(let typeName):
            "This file type (\(typeName)) isn't supported. WheelAnything converts PNG, JPEG, HEIC, HEIF, GIF and WebP "
                + "images, and PDFs."
        }
    }
}

/// Identifies dropped files by their content.
public protocol FileDetecting: Sendable {
    func detect(_ url: URL) -> Result<DetectedFile, DetectionFailure>
}

/// Detects formats from file content with PDFKit and Image I/O, without decoding pixels.
///
/// Limitation: an image cut off after its header passes detection, because Image I/O only
/// reads pixel data when the image is decoded. Such files fail later, during conversion,
/// where the output pipeline validates every result (PLAN.md §6).
public struct FileDetector: FileDetecting {
    public init() {}

    public func detect(_ url: URL) -> Result<DetectedFile, DetectionFailure> {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        } catch {
            return .failure(.cannotRead(reason: error.localizedDescription))
        }
        if values.isDirectory == true { return .failure(.isFolder) }
        if values.fileSize == 0 { return .failure(.empty) }

        let format: InputFormat
        do {
            if try startsLikePDF(url) {
                // PDFKit returns nil or zero pages for a file it cannot parse.
                guard let document = PDFDocument(url: url), document.pageCount > 0 else {
                    return .failure(.damaged(.pdf))
                }
                format = .pdf
            } else {
                switch detectImage(url) {
                case .success(let imageFormat): format = imageFormat
                case .failure(let failure): return .failure(failure)
                }
            }
        } catch {
            return .failure(.cannotRead(reason: error.localizedDescription))
        }

        let extensionType = UTType(filenameExtension: url.pathExtension)
        return .success(
            DetectedFile(
                url: url, format: format,
                extensionMatchesContent: extensionType?.conforms(to: format.utType) ?? false))
    }

    /// The PDF specification allows the `%PDF-` marker anywhere in the first 1024 bytes.
    private func startsLikePDF(_ url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 1024) ?? Data()
        return header.range(of: Data("%PDF-".utf8)) != nil
    }

    private func detectImage(_ url: URL) -> Result<InputFormat, DetectionFailure> {
        // No type hint is passed, so Image I/O identifies the format from the bytes, not the name.
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let identifier = CGImageSourceGetType(source) as String?
        else {
            return .failure(.notSupported(typeName: Self.typeName(forExtensionOf: url)))
        }
        guard let format = InputFormat(imageIOType: identifier) else {
            return .failure(.notSupported(typeName: UTType(identifier)?.localizedDescription ?? identifier))
        }
        // Reading the properties parses the header only. Missing dimensions mean the header
        // is cut off or corrupt.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        guard properties?[kCGImagePropertyPixelWidth] != nil else {
            return .failure(.damaged(format))
        }
        return .success(format)
    }

    private static func typeName(forExtensionOf url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.localizedDescription ?? "Unknown"
    }
}
