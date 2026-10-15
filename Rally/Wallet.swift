import Foundation

// Your receipts. Right-swipe pockets a card; ❤️ follows a candidate. All on device.
struct SavedItem: Identifiable, Codable, Hashable {
    let id: String
    let candidate: String
    let savedAt: Date
    var post: Post? = nil
    var fact: Fact? = nil

    var title: String { fact?.title ?? (post != nil ? "Posted on \(post!.platformLabel)" : "Receipt") }
    var text: String { fact?.text ?? post?.text ?? "" }
    var source: String { fact?.source ?? post?.account.handle ?? "" }
    var url: URL? { fact?.url ?? post?.url }
    var category: String { fact?.category ?? "post" }
}

@Observable
final class Wallet {
    private(set) var items: [SavedItem] = []
    private(set) var follows: Set<String> = []
    var lastSavedID: String?                      // for the fly-in animation

    private let itemsKey = "rally.wallet", followsKey = "rally.follows"

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: itemsKey), let s = try? JSONDecoder().decode([SavedItem].self, from: data) { items = s }
        if let f = d.stringArray(forKey: followsKey) { follows = Set(f) }
    }

    func has(_ id: String) -> Bool { items.contains { $0.id == id } }

    func pocket(_ item: FeedItem, candidate: String) {
        switch item {
        case .post(let p): save(id: item.id, candidate: candidate, post: p, fact: nil)
        case .fact(let f): save(id: item.id, candidate: candidate, post: nil, fact: f)
        }
    }

    func pocket(_ item: FYPItem) {
        switch item {
        case .post(let p, let c): save(id: item.id, candidate: c.name, post: p, fact: nil)
        case .fact(let f, let c): save(id: item.id, candidate: c.name, post: nil, fact: f)
        case .faceoff: break    // games aren't pocketable
        }
    }

    private func save(id: String, candidate: String, post: Post?, fact: Fact?) {
        guard !has(id) else { return }
        var s = SavedItem(id: id, candidate: candidate, savedAt: .now)
        s.post = post
        s.fact = fact
        items.insert(s, at: 0)
        lastSavedID = id
        persist()
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    func toggleFollow(_ candidate: String) {
        if follows.contains(candidate) { follows.remove(candidate) } else { follows.insert(candidate) }
        UserDefaults.standard.set(Array(follows), forKey: followsKey)
    }

    func isFollowing(_ candidate: String) -> Bool { follows.contains(candidate) }

    var byCandidate: [(String, [SavedItem])] {
        Dictionary(grouping: items, by: \.candidate).sorted { $0.value.count > $1.value.count }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: itemsKey) }
    }
}

// Anonymous signal: what people care about. No user ID, no device ID — a tally.
extension Backend {
    static func signal(cardID: String, candidate: String, category: String, liked: Bool) {
        var req = URLRequest(url: base.deletingLastPathComponent().appending(path: "api/signal"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Rally/0.1 (iOS; github.com/anya-decarlo/Rally)", forHTTPHeaderField: "User-Agent")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "cardId": cardID, "candidate": candidate, "category": category, "liked": liked])
        URLSession.shared.dataTask(with: req).resume()     // fire and forget; a 404 today is fine
    }
}
