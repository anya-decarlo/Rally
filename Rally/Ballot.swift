import Foundation

// Loads data/ballot.json. Edit the JSON, not this file, when the ballot changes.
enum Ballot {
    static let file: BallotFile? = PostStore.loadBundled("ballot", as: BallotFile.self)
    static let contests: [Contest] = file?.contests ?? []

    static func contests(in group: ContestGroup) -> [Contest] {
        contests.filter { $0.group == group }
    }

    static var allCandidates: [Candidate] { contests.flatMap(\.candidates) }
}
