import Foundation

// The fashion library. Images live in data/fashion/, described by looks.json.
// Drop a photo in the folder + a line in the manifest — no project changes needed.

struct Look: Identifiable, Codable, Hashable {
    let id: String
    let person: String          // who's wearing it — matches ballot name when it can
    let file: String            // filename inside data/fashion/
    var event: String? = nil    // "White House Correspondents' Dinner", etc.
    var date: String? = nil
    var source: String? = nil   // credit, e.g. "Getty / Mark Wilson"
    var url: URL? = nil         // where the photo was published

    var imageURL: URL? {
        Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "fashion")
            ?? Bundle.main.url(forResource: file, withExtension: nil)
    }
}

struct FashionFile: Codable {
    let looks: [Look]
    var faceoffs: [Faceoff] = []
}

// A matchup. closesAt is a real deadline — when it passes, voting is over.
struct Faceoff: Identifiable, Codable, Hashable {
    let id: String
    var title: String = "Who wore it best?"
    let lookIds: [String]
    let closesAt: Date

    var isOpen: Bool { closesAt > .now }
    func looks(in store: FashionStore) -> [Look] {
        lookIds.compactMap { id in store.looks.first { $0.id == id } }
    }
}

@Observable
final class FashionStore {
    private(set) var looks: [Look] = []
    private(set) var faceoffs: [Faceoff] = []
    private(set) var votes: [String: String] = [:]            // faceoffId → lookId, one vote per device
    private(set) var results: [String: Backend.FaceoffResults] = [:]  // live tallies from the backend
    private let votesKey = "rally.faceoffs"

    init() {
        if let url = Bundle.main.url(forResource: "looks", withExtension: "json", subdirectory: "fashion"),
           let data = try? Data(contentsOf: url) {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            if let file = try? d.decode(FashionFile.self, from: data) {
                looks = file.looks
                faceoffs = file.faceoffs
            }
        }
        if let data = UserDefaults.standard.data(forKey: votesKey),
           let v = try? JSONDecoder().decode([String: String].self, from: data) { votes = v }
    }

    func looks(for person: String) -> [Look] { looks.filter { $0.person == person } }

    // Who has enough looks to play against each other.
    var players: [String] {
        Dictionary(grouping: looks, by: \.person).filter { $0.value.count > 0 }.keys.sorted()
    }

    func pick(in faceoff: Faceoff) -> String? { votes[faceoff.id] }

    func vote(_ faceoff: Faceoff, for look: Look) {
        guard faceoff.isOpen, votes[faceoff.id] == nil else { return }
        votes[faceoff.id] = look.id
        if let data = try? JSONEncoder().encode(votes) { UserDefaults.standard.set(data, forKey: votesKey) }
        Backend.faceoffVote(faceoffID: faceoff.id, lookID: look.id)
        Task { await refreshResults(faceoff) }
    }

    @MainActor
    func refreshResults(_ faceoff: Faceoff) async {
        if let r = await Backend.faceoffResults(faceoffID: faceoff.id) {
            results[faceoff.id] = r
        }
    }

    // Demo helper — clears your local votes so the card shows pre-vote state again.
    func resetVotes() {
        votes = [:]
        UserDefaults.standard.removeObject(forKey: votesKey)
    }
}
