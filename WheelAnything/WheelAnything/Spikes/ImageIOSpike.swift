#if DEBUG
import UniformTypeIdentifiers
import WheelCore

/// Spike 4: which formats can Image I/O read and write on this Mac?
enum ImageIOSpike {
    static func run() throws {
        let capabilities = ImageIOCapabilities.current()
        SpikeLog.line("Readable (\(capabilities.readableTypeIdentifiers.count)): "
            + capabilities.readableTypeIdentifiers.sorted().joined(separator: ", "))
        SpikeLog.line("Writable (\(capabilities.writableTypeIdentifiers.count)): "
            + capabilities.writableTypeIdentifiers.sorted().joined(separator: ", "))
        for (name, type) in [("PNG", UTType.png), ("JPEG", .jpeg), ("HEIC", .heic), ("HEIF", .heif), ("WebP", .webP)] {
            SpikeLog.line("\(name): readable=\(capabilities.canRead(type)) writable=\(capabilities.canWrite(type))")
        }
    }
}
#endif
