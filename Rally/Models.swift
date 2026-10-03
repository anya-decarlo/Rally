import Foundation

// The ballot is data (data/ballot.json), shared by the app and the pipeline.
// A candidate's name here is the join key for posts, facts, clips, and portraits.

enum Party: String, Codable {
    case democrat, republican, green, independent, oneHome, nonpartisan

    var short: String {
        switch self {
        case .democrat: "D"
        case .republican: "R"
        case .green: "Green"
        case .independent: "I"
        case .oneHome: "One Home"
        case .nonpartisan: "NP"
        }
    }

    var label: String {
        switch self {
        case .democrat: "Democrat"
        case .republican: "Republican"
        case .green: "DC Statehood Green"
        case .independent: "Independent"
        case .oneHome: "One Home"
        case .nonpartisan: "Nonpartisan"
        }
    }
}

struct SocialAccount: Codable, Hashable {
    let platform: String
    let handle: String
    let kind: String
}

struct Candidate: Identifiable, Hashable, Codable {
    var id: String { name }
    let name: String
    let party: Party
    var incumbent = false
    var writeIn = false
    var wikipedia: String? = nil
    var accounts: [SocialAccount] = []

    enum CodingKeys: String, CodingKey { case name, party, incumbent, writeIn, wikipedia, accounts }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        party = try c.decode(Party.self, forKey: .party)
        incumbent = try c.decodeIfPresent(Bool.self, forKey: .incumbent) ?? false
        writeIn = try c.decodeIfPresent(Bool.self, forKey: .writeIn) ?? false
        wikipedia = try c.decodeIfPresent(String.self, forKey: .wikipedia)
        accounts = try c.decodeIfPresent([SocialAccount].self, forKey: .accounts) ?? []
    }
}

enum ContestGroup: String, Codable, CaseIterable {
    case federal = "Federal"
    case districtWide = "District-wide"
    case ward = "Ward"
    case education = "Education"
    case neighborhood = "Neighborhood"
    case ballotMeasures = "Ballot Measures"
}

struct Contest: Identifiable, Hashable, Codable {
    var id: String { office }
    let group: ContestGroup
    let office: String
    let candidates: [Candidate]
    var note: String? = nil
}

struct BallotFile: Codable {
    let place: String
    let election: String
    let contests: [Contest]
}
