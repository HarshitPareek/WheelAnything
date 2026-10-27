#if DEBUG
import AppKit

/// Spike 5: where can the sandboxed app write, and do security-scoped bookmarks
/// survive a relaunch?
enum OutputSpike {
    private static let bookmarkKey = "spike.grantedFolderBookmark"

    /// 5a: write to Downloads (allowed by the Downloads read-write entitlement).
    static func writeToDownloads() throws {
        let downloads = try FileManager.default.url(
            for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        // Inside the sandbox this is a path in the app's container that links to the
        // real ~/Downloads; resolving the link shows where the file really lands.
        SpikeLog.line("Downloads URL as seen by the app: \(downloads.path)")
        SpikeLog.line("Resolved: \(downloads.resolvingSymlinksInPath().path)")
        let file = downloads.appending(path: "WheelAnything spike \(UUID().uuidString.prefix(8)).txt")
        try Data("spike".utf8).write(to: file, options: .withoutOverwriting)
        let readBack = try String(contentsOf: file, encoding: .utf8)
        SpikeLog.line("Wrote and read back \(file.lastPathComponent): \(readBack == "spike" ? "OK" : "MISMATCH")")
        try FileManager.default.removeItem(at: file)
        SpikeLog.line("Removed the test file again")
    }

    /// 5b (headless form): write into the folder of `path` without any grant.
    static func writeNextTo(path: String?) throws {
        guard let path else { throw SpikeFailure("usage: -spike write-next-to <file path>") }
        SpikeLog.line(attemptWrite(nextTo: URL(filePath: path)))
    }

    /// Tries to create a sibling file next to `file` and reports the exact outcome.
    /// The test file is removed again on success.
    static func attemptWrite(nextTo file: URL) -> String {
        let sibling = file.deletingLastPathComponent()
            .appending(path: "\(file.deletingPathExtension().lastPathComponent) spike-sibling.txt")
        do {
            try Data("spike".utf8).write(to: sibling, options: .withoutOverwriting)
            try? FileManager.default.removeItem(at: sibling)
            return "WRITE NEXT TO \(file.lastPathComponent): SUCCEEDED (\(sibling.path)), test file removed"
        } catch let error as NSError {
            let underlying = (error.userInfo[NSUnderlyingErrorKey] as? NSError).map { " underlying=\($0.domain) \($0.code) \($0.localizedDescription)" } ?? ""
            return "WRITE NEXT TO \(file.lastPathComponent): FAILED \(error.domain) \(error.code) \"\(error.localizedDescription)\"\(underlying)"
        }
    }

    /// 5c: ask the user for a folder, prove we can write there, and save a
    /// security-scoped bookmark so the grant survives a relaunch.
    @MainActor static func grantFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Grant Access"
        panel.message = "Spike: choose the folder that contains the file you dropped."
        // An agent app (no Dock icon) is never frontmost on its own; without this the
        // open panel can appear behind other windows.
        NSApp.activate()
        guard panel.runModal() == .OK, let folder = panel.url else {
            SpikeLog.line("GRANT: user cancelled")
            return nil
        }
        SpikeLog.line("GRANT: user chose \(folder.path)")
        SpikeLog.line("GRANT write test: " + attemptWrite(nextTo: folder.appending(path: "probe")))
        do {
            let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            SpikeLog.line("BOOKMARK saved (\(bookmark.count) bytes). Quit and relaunch to test restoring it.")
        } catch {
            SpikeLog.line("BOOKMARK save FAILED: \(error)")
        }
        return folder
    }

    /// 5c after relaunch: resolve the saved bookmark and write inside the folder.
    /// When `file` is given, writes next to that file instead (the "after grant" retry).
    @MainActor static func useSavedBookmark(nextTo file: URL? = nil) {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            SpikeLog.line("BOOKMARK: none saved yet")
            return
        }
        do {
            var isStale = false
            let folder = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            // The bookmark only gives permission between start/stop calls; access must
            // be released again or the process leaks kernel resources.
            let started = folder.startAccessingSecurityScopedResource()
            defer { if started { folder.stopAccessingSecurityScopedResource() } }
            SpikeLog.line("BOOKMARK resolved \(folder.path) stale=\(isStale) startAccessing=\(started)")
            SpikeLog.line("BOOKMARK write test: " + attemptWrite(nextTo: file ?? folder.appending(path: "probe")))
        } catch {
            SpikeLog.line("BOOKMARK resolve FAILED: \(error)")
        }
    }
}
#endif
