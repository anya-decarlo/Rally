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

    struct FaceoffResults: Codable {
        let faceoffId: String
        let total: Int
        let votes: [String: Int]
    }

    // Anonymous one-tap vote. 404s harmlessly until the endpoint is deployed.
    static func faceoffVote(faceoffID: String, lookID: String) {
        var req = URLRequest(url: base.deletingLastPathComponent().appending(path: "api/faceoffs/vote"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Rally/0.1 (iOS; github.com/anya-decarlo/Rally)", forHTTPHeaderField: "User-Agent")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["faceoffId": faceoffID, "lookId": lookID])
        URLSession.shared.dataTask(with: req).resume()
    }

    static func faceoffResults(faceoffID: String) async -> FaceoffResults? {
        var c = URLComponents(url: base.deletingLastPathComponent().appending(path: "api/faceoffs/results"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "id", value: faceoffID)]
        return await fetch(c.url!, as: FaceoffResults.self)
    }
}
