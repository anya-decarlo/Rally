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

// posts.json: bundled copy on launch, replaced wholesale by the backend when it answers.
@Observable
final class PostStore {
    private(set) var posts: [Post] = []
    private(set) var generatedAt: String = ""
    private(set) var isLive = false

    init() {
        if let file = PostStore.loadBundled("posts", as: PostsFile.self) { apply(file) }
    }

    func posts(for candidate: Candidate) -> [Post] {
        posts.filter { $0.candidate == candidate.name }
    }

    @MainActor
    func refresh() async {
        guard let file = await Backend.fetch(Backend.posts, as: PostsFile.self) else { return }
        apply(file)
        isLive = true
    }

    private func apply(_ file: PostsFile) {
        posts = file.posts
        generatedAt = file.generatedAt
    }
}
