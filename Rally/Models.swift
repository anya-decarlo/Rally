import Foundation

// Only what we actually know today. Fields get added when the data exists.

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

struct Candidate: Identifiable, Hashable, Codable {
    var id: String { name }
    let name: String
    let party: Party
    var incumbent = false
    var writeIn = false
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
