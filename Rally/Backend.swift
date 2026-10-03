import Foundation

// One place for the backend. Remote is authoritative; bundled JSON is the offline fallback.
enum Backend {
    static let base = URL(string: "https://rally-backend.geraniumlabs.workers.dev/rally")!
    static var posts: URL { base.appending(path: "posts.json") }
    static var facts: URL { base.appending(path: "facts.json") }
    static var videos: URL { base.appending(path: "videos.json") }

    static func fetch<T: Decodable>(_ url: URL, as type: T.Type) async -> T? {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        req.setValue("Rally/0.1 (iOS; github.com/anya-decarlo/Rally)", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
