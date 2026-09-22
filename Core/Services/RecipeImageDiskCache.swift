import Foundation

enum RecipeImageDiskCache {
    // Serialize reads, writes and eviction; cancelled image loads must not repopulate evicted files.
    private static let lock = NSLock()
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recipe-images", isDirectory: true)
    }

    // MARK: - Full Images

    static func load(for imagePath: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let fileURL = cacheDirectory.appendingPathComponent(sanitized(imagePath))
        return try? Data(contentsOf: fileURL)
    }

    static func save(_ data: Data, for imagePath: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !Task.isCancelled else { return }
        let dir = cacheDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(sanitized(imagePath))
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Thumbnails

    static func loadThumb(for imagePath: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let fileURL = cacheDirectory.appendingPathComponent("thumb_" + sanitized(imagePath))
        return try? Data(contentsOf: fileURL)
    }

    static func saveThumb(_ data: Data, for imagePath: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !Task.isCancelled else { return }
        let dir = cacheDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("thumb_" + sanitized(imagePath))
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Management

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    static func remove(for imagePath: String) {
        lock.lock()
        defer { lock.unlock() }
        let dir = cacheDirectory
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(sanitized(imagePath)))
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("thumb_" + sanitized(imagePath)))
    }

    private static func sanitized(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "_")
    }
}
