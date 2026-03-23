import Foundation

enum RecipeImageDiskCache {
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recipe-images", isDirectory: true)
    }

    // MARK: - Full Images

    static func load(for imagePath: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(sanitized(imagePath))
        return try? Data(contentsOf: fileURL)
    }

    static func save(_ data: Data, for imagePath: String) {
        let dir = cacheDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(sanitized(imagePath))
        try? data.write(to: fileURL)
    }

    // MARK: - Thumbnails

    static func loadThumb(for imagePath: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent("thumb_" + sanitized(imagePath))
        return try? Data(contentsOf: fileURL)
    }

    static func saveThumb(_ data: Data, for imagePath: String) {
        let dir = cacheDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("thumb_" + sanitized(imagePath))
        try? data.write(to: fileURL)
    }

    // MARK: - Management

    static func clear() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    private static func sanitized(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "_")
    }
}
