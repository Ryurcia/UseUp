import Foundation

enum AvatarCache {
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatars", isDirectory: true)
    }

    static func load(for avatarPath: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(sanitized(avatarPath))
        return try? Data(contentsOf: fileURL)
    }

    static func save(_ data: Data, for avatarPath: String) {
        let dir = cacheDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(sanitized(avatarPath))
        try? data.write(to: fileURL)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    private static func sanitized(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "_")
    }
}
