import Foundation

// facts.json + videos.json. Both human-verified, both link to their source.

struct FactsFile: Codable {
    let generatedAt: String
    let candidates: [String: CandidateExtras]
}

struct CandidateExtras: Codable {
    let facts: [Fact]
    let portrait: Portrait?
}

struct Fact: Codable, Hashable, Identifiable {
    var id: String { text }
    let text: String
    let source: String
    let url: URL
    var category: String? = nil     // "bio" | "money" | "record" | "vote" — optional, missing is fine
}

struct Portrait: Codable, Hashable {
    let file: String
    let source: URL
    let license: String
    let credit: String
    let page: URL
}

struct VideosFile: Codable {
    let generatedAt: String
    let videos: [String: [Clip]]
}

struct Clip: Codable, Hashable, Identifiable {
    let id: String
    let platform: String
    let title: String
    let channel: String
    let channelUrl: URL?
    let publishedAt: String?
    let duration: Int?
    let thumb: URL?
    let url: URL
    let embedUrl: URL
    let verifiedBy: String

    var durationLabel: String {
        guard let d = duration else { return "" }
        return String(format: "%d:%02d", d / 60, d % 60)
    }
}

extension PostStore {
    static func loadBundled<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

@Observable
final class ExtrasStore {
    private(set) var extras: [String: CandidateExtras] = [:]
    private(set) var clips: [String: [Clip]] = [:]

    init() {
        extras = PostStore.loadBundled("facts", as: FactsFile.self)?.candidates ?? [:]
        clips = PostStore.loadBundled("videos", as: VideosFile.self)?.videos ?? [:]
    }

    @MainActor
    func refresh() async {
        async let f = Backend.fetch(Backend.facts, as: FactsFile.self)
        async let v = Backend.fetch(Backend.videos, as: VideosFile.self)
        if let f = await f { extras = f.candidates }
        if let v = await v { clips = v.videos }
    }

    func facts(for c: Candidate) -> [Fact] { extras[c.name]?.facts ?? [] }
    func portrait(for c: Candidate) -> Portrait? { extras[c.name]?.portrait }
    func clips(for c: Candidate) -> [Clip] { clips[c.name] ?? [] }
}
