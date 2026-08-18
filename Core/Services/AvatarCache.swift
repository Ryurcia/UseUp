import Foundation

enum AvatarCache {
    private static let memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 50
        return cache
    }()

    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatars", isDirectory: true)
    }

    static func load(for avatarPath: String) -> Data? {
        let key = avatarPath as NSString
        if let cached = memoryCache.object(forKey: key) {
            return cached as Data
        }
        let fileURL = cacheDirectory.appendingPathComponent(sanitized(avatarPath))
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        memoryCache.setObject(data as NSData, forKey: key)
        return data
    }

    static func save(_ data: Data, for avatarPath: String) {
        memoryCache.setObject(data as NSData, forKey: avatarPath as NSString)
        let dir = cacheDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(sanitized(avatarPath))
        try? data.write(to: fileURL)
    }

    static func clear() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    private static func sanitized(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "_")
    }
}
