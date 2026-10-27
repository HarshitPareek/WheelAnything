import ImageIO
import UniformTypeIdentifiers

/// The image formats Image I/O can read and write on the Mac the app is running on.
///
/// This is asked at runtime instead of hard-coded because the answer depends on the
/// macOS version and hardware (PLAN.md §3.1: WebP is offered only if Image I/O
/// reports it; HEIC writing depends on the system's HEVC encoder).
public struct ImageIOCapabilities: Sendable, Equatable {
    /// Uniform Type Identifiers Image I/O can decode, such as `public.png`.
    public let readableTypeIdentifiers: Set<String>
    /// Uniform Type Identifiers Image I/O can encode.
    public let writableTypeIdentifiers: Set<String>

    public init(readableTypeIdentifiers: Set<String>, writableTypeIdentifiers: Set<String>) {
        self.readableTypeIdentifiers = readableTypeIdentifiers
        self.writableTypeIdentifiers = writableTypeIdentifiers
    }

    /// Asks Image I/O on the running system.
    public static func current() -> ImageIOCapabilities {
        ImageIOCapabilities(
            readableTypeIdentifiers: identifiers(in: CGImageSourceCopyTypeIdentifiers()),
            writableTypeIdentifiers: identifiers(in: CGImageDestinationCopyTypeIdentifiers())
        )
    }

    public func canRead(_ type: UTType) -> Bool {
        readableTypeIdentifiers.contains(type.identifier)
    }

    public func canWrite(_ type: UTType) -> Bool {
        writableTypeIdentifiers.contains(type.identifier)
    }

    /// Image I/O returns a CFArray of CFStrings; bridge it to Swift strings.
    private static func identifiers(in array: CFArray) -> Set<String> {
        Set((array as? [String]) ?? [])
    }
}
