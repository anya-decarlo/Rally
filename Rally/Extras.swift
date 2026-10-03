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
    var category: String? = nil     // "bio" | "money" | "record" | "vote" | "pair" | "endorsement" | "identity"
    var title: String? = nil        // plain-English headline so the card makes sense cold
}

// What this user swipes right on. Per candidate, per category. Lives on device.
@Observable
final class Taste {
    private(set) var scores: [String: Int] = [:]
    private let key = "rally.taste"

    init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode([String: Int].self, from: d) { scores = s }
    }

    func score(_ candidate: String, _ category: String) -> Int {
        (scores["\(candidate)|\(category)"] ?? 0) + (scores["*|\(category)"] ?? 0)
    }

    func record(_ candidate: String, _ category: String, liked: Bool) {
        let d = liked ? 1 : -1
        scores["\(candidate)|\(category)", default: 0] += d
        scores["*|\(category)", default: 0] += d
        if let data = try? JSONEncoder().encode(scores) { UserDefaults.standard.set(data, forKey: key) }
    }

    // 1.0 = neutral; swipe-right categories float up, swipe-left ones sink.
    func weight(_ candidate: String, _ category: String) -> Double {
        let s = Double(max(-6, min(6, score(candidate, category))))
        return pow(1.5, s)
    }
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

    // Bio facts are human-curated in the repo and always win. The backend contributes
    // money / record / vote facts only — its bio (Wikipedia) facts are never shown.
    @MainActor
    func refresh() async {
        async let f = Backend.fetch(Backend.facts, as: FactsFile.self)
        async let v = Backend.fetch(Backend.videos, as: VideosFile.self)
        if let remote = await f {
            var merged = extras
            for (name, r) in remote.candidates {
                let local = extras[name]?.facts ?? []
                let bio = local.filter { ($0.category ?? "bio") == "bio" }
                let localData = local.filter { $0.category != nil && $0.category != "bio" }
                let seen = Set(localData.map(\.text))
                let remoteData = r.facts.filter { $0.category != nil && $0.category != "bio" && !seen.contains($0.text) }
                merged[name] = CandidateExtras(facts: bio + localData + remoteData, portrait: extras[name]?.portrait ?? r.portrait)
            }
            extras = merged
        }
        if let v = await v { clips = v.videos }
    }

    func facts(for c: Candidate) -> [Fact] { extras[c.name]?.facts ?? [] }
    func portrait(for c: Candidate) -> Portrait? { extras[c.name]?.portrait }
    func clips(for c: Candidate) -> [Clip] { clips[c.name] ?? [] }
}
