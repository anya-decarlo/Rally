import Foundation

// Mirrors pipeline/schema.md exactly. The app reads only this shape.

struct PostsFile: Codable {
    let generatedAt: String
    let posts: [Post]
}

struct Post: Identifiable, Codable, Hashable {
    let id: String
    let platform: String
    let candidate: String
    let account: Account
    let text: String
    let createdAt: String
    let url: URL
    let media: [Media]
    let metrics: Metrics
    var quoted: Quoted? = nil

    struct Account: Codable, Hashable {
        let handle: String
        let displayName: String
        let avatar: URL?
        let kind: String            // "official" | "personal"
    }
    struct Media: Codable, Hashable {
        let type: String            // "image" | "video" | "link"
        let url: URL?
        var thumb: URL? = nil
        var alt: String? = nil
        var title: String? = nil
    }
    struct Metrics: Codable, Hashable {
        let likes: Int, reposts: Int, replies: Int
    }
    struct Quoted: Codable, Hashable {
        let handle: String, text: String, url: URL
    }

    var date: Date? { ISO8601DateFormatter.parse(createdAt) }
    var isOfficial: Bool { account.kind == "official" }
    var image: Media? { media.first { $0.type == "image" } }
    var video: Media? { media.first { $0.type == "video" } }
    var link: Media? { media.first { $0.type == "link" } }
    var platformLabel: String { platform == "bluesky" ? "Bluesky" : platform == "x" ? "X" : platform }
}

// Timestamps arrive verbatim from each platform — with or without fractional seconds. Accept both.
extension ISO8601DateFormatter {
    private static let withMillis: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func parse(_ s: String) -> Date? { withMillis.date(from: s) ?? plain.date(from: s) }
}

// Loads posts.json. Today: the bundled copy. Tomorrow: the backend URL, same shape.
@Observable
final class PostStore {
    private(set) var posts: [Post] = []
    private(set) var generatedAt: String = ""

    init() { loadBundled() }

    func posts(for candidate: Candidate) -> [Post] {
        posts.filter { $0.candidate == candidate.name }
    }

    private func loadBundled() {
        guard let url = Bundle.main.url(forResource: "posts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PostsFile.self, from: data) else { return }
        posts = file.posts
        generatedAt = file.generatedAt
    }

    func load(from remote: URL) async {
        guard let (data, _) = try? await URLSession.shared.data(from: remote),
              let file = try? JSONDecoder().decode(PostsFile.self, from: data) else { return }
        posts = file.posts
        generatedAt = file.generatedAt
    }
}
