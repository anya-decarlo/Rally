import Foundation

// The map of who governs what — data/jurisdictions/<state>.json, generated
// by pipeline/jurisdictions.py. A jurisdiction holds seats (elected offices)
// and contains or overlaps other jurisdictions. A voter's ballot is a stack:
// state + county + city + districts — every contest in the stack is yours.

enum JurisdictionKind: String, Codable, CaseIterable {
    case state, county, city, district

    var label: String {
        switch self {
        case .state: "STATE GOVERNMENT"
        case .county: "COUNTY GOVERNMENT"
        case .city: "CITY GOVERNMENT"
        case .district: "INDEPENDENT LOCAL GOVERNMENT"
        }
    }

    var tagline: String {
        switch self {
        case .state: "Governor · Legislature · State courts · State agencies"
        case .county: "Supervisors · Sheriff · District attorney · County offices"
        case .city: "Mayor · City council · Planning · Zoning"
        case .district: "School districts · Fire · Water · Transit authorities"
        }
    }
}

struct Seat: Hashable, Codable {
    let office: String
    var seats = 0            // 0 = varies / unknown
    var elected = ""         // "districts" | "at-large" | "wide" | "retention"
    var note: String? = nil
    var federal = false

    enum CodingKeys: String, CodingKey { case office, seats, elected, note, federal }

    init(office: String, seats: Int = 0, elected: String = "", note: String? = nil, federal: Bool = false) {
        self.office = office; self.seats = seats; self.elected = elected
        self.note = note; self.federal = federal
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        office = try c.decode(String.self, forKey: .office)
        seats = try c.decodeIfPresent(Int.self, forKey: .seats) ?? 0
        elected = try c.decodeIfPresent(String.self, forKey: .elected) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note)
        federal = try c.decodeIfPresent(Bool.self, forKey: .federal) ?? false
    }
}

struct Jurisdiction: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let kind: JurisdictionKind
    var type: String? = nil          // "City" | "Town"
    var districtKind: String? = nil  // districts: school / water / transit / …
    var parent: String? = nil
    var consolidated = false         // SF: the city IS the county
    var unincorporated = false       // county governs non-city residents directly
    var covers: String? = nil        // districts: human description of coverage
    var seats: [Seat] = []

    enum CodingKeys: String, CodingKey {
        case id, name, kind, type, districtKind, parent, consolidated, unincorporated, covers, seats
    }

    init(id: String, name: String, kind: JurisdictionKind) {
        self.id = id; self.name = name; self.kind = kind
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(JurisdictionKind.self, forKey: .kind)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        districtKind = try c.decodeIfPresent(String.self, forKey: .districtKind)
        parent = try c.decodeIfPresent(String.self, forKey: .parent)
        consolidated = try c.decodeIfPresent(Bool.self, forKey: .consolidated) ?? false
        unincorporated = try c.decodeIfPresent(Bool.self, forKey: .unincorporated) ?? false
        covers = try c.decodeIfPresent(String.self, forKey: .covers)
        seats = try c.decodeIfPresent([Seat].self, forKey: .seats) ?? []
    }

    var seatSummary: String {
        seats.prefix(4).map { s in
            s.seats > 0 ? "\(s.office) (\(s.seats))" : s.office
        }.joined(separator: " · ")
    }
}

struct DistrictKind: Hashable, Codable {
    let kind: String
    let count: String
    var note: String? = nil
}

// Per-place naming for the four levels — CA says COUNTY GOVERNMENT,
// DC's wards aren't counties, so the file can override labels.
struct LevelMeta: Hashable, Codable {
    let kind: String
    let label: String
    let tagline: String
}

struct JurisdictionFile: Codable {
    let state: String
    let levels: [String]
    var levelsMeta: [LevelMeta]? = nil
    let districtCatalog: [DistrictKind]
    let jurisdictions: [Jurisdiction]

    func find(_ id: String) -> Jurisdiction? { jurisdictions.first { $0.id == id } }
    func kind(_ k: JurisdictionKind) -> [Jurisdiction] { jurisdictions.filter { $0.kind == k } }
    func children(of id: String) -> [Jurisdiction] { jurisdictions.filter { $0.parent == id } }
    var stateJurisdiction: Jurisdiction? { jurisdictions.first { $0.kind == .state } }

    // The offices that govern an address: everything at or above your level
    // plus the independent districts covering you.
    func stack(county: String, city: String?, districts: [String] = []) -> [Jurisdiction] {
        var out = [Jurisdiction]()
        if let s = stateJurisdiction { out.append(s) }
        if let c = find(county) { out.append(c) }
        if let city, let j = find(city) { out.append(j) }
        out += districts.compactMap(find)
        return out
    }
}

// MARK: - Activity — what they actually did, between elections
// Jurisdictions/seats are the structure; ActivityItems are the stream.
// data/activity/<state>.json, generated by pipeline/activity.py.

struct ActivityKind: Hashable, Codable {
    let kind: String
    let label: String
    let example: String
}

struct ActivitySource: Hashable, Codable {
    let name: String
    let provides: String
    let url: String
}

struct ExplainerPath: Hashable, Codable {
    let id: String
    let label: String
    let jurisdiction: String
    let steps: [String]
}

struct Explainer: Hashable, Codable {
    let topic: String
    let paths: [ExplainerPath]
    let note: String
}

struct ActivityItem: Identifiable, Hashable, Codable {
    let id: String
    let kind: String             // one of ActivityKind.kind
    let jurisdiction: String     // jurisdiction id, or "us" for federal
    let date: String
    let title: String
    var detail: String? = nil
    var actors: [String] = []
    var bill: String? = nil
    var crossLevel = false       // state↔federal interaction
    let source: String           // the receipt — required, it's the house rule

    enum CodingKeys: String, CodingKey {
        case id, kind, jurisdiction, date, title, detail, actors, bill, crossLevel, source
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(String.self, forKey: .kind)
        jurisdiction = try c.decode(String.self, forKey: .jurisdiction)
        date = try c.decode(String.self, forKey: .date)
        title = try c.decode(String.self, forKey: .title)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        actors = try c.decodeIfPresent([String].self, forKey: .actors) ?? []
        bill = try c.decodeIfPresent(String.self, forKey: .bill)
        crossLevel = try c.decodeIfPresent(Bool.self, forKey: .crossLevel) ?? false
        source = try c.decode(String.self, forKey: .source)
    }
}

struct ActivityFile: Codable {
    let state: String
    let activityKinds: [ActivityKind]
    let sources: [ActivitySource]
    let explainer: Explainer
    let items: [ActivityItem]

    // The tracker as a given voter sees it — everything in their stack.
    func items(in stack: Set<String>) -> [ActivityItem] {
        items.filter { stack.contains($0.jurisdiction) || $0.jurisdiction == "us" }
    }
}

// MARK: - Legislation — every bill is a card, every card has its people
// data/legislation/<state>.json, generated by pipeline/legislation.py.

struct BillPerson: Hashable, Codable {
    let name: String
    let role: String           // author · principal coauthor · coauthor · sponsor
    let seat: String           // "State Senate · D-11 · SF"
    var pid: String? = nil     // ocd-person/… — joins to the roster
}

struct BillAction: Hashable, Codable {
    let date: String
    let action: String
}

struct Bill: Identifiable, Hashable, Codable {
    let id: String
    let code: String           // "SB 79" — what it's called
    let chamber: String        // senate | assembly
    let title: String
    let summary: String
    let status: String         // law | vetoed | enjoined | in committee | …
    var stage: Int             // index into LegislationFile.stages
    var crossLevel = false     // this bill is in a state↔federal fight
    var introduced: String? = nil
    var lastAction: BillAction? = nil
    var people: [BillPerson] = []
    var subjects: [String] = []
    let source: String         // leginfo — the receipt

    enum CodingKeys: String, CodingKey {
        case id, code, chamber, title, summary, status, stage, crossLevel,
             introduced, lastAction, people, subjects, source
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        code = try c.decode(String.self, forKey: .code)
        chamber = try c.decode(String.self, forKey: .chamber)
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decode(String.self, forKey: .summary)
        status = try c.decode(String.self, forKey: .status)
        stage = try c.decodeIfPresent(Int.self, forKey: .stage) ?? 0
        crossLevel = try c.decodeIfPresent(Bool.self, forKey: .crossLevel) ?? false
        introduced = try c.decodeIfPresent(String.self, forKey: .introduced)
        lastAction = try c.decodeIfPresent(BillAction.self, forKey: .lastAction)
        people = try c.decodeIfPresent([BillPerson].self, forKey: .people) ?? []
        subjects = try c.decodeIfPresent([String].self, forKey: .subjects) ?? []
        source = try c.decode(String.self, forKey: .source)
    }

    // What kind of measure it is — derived from the code prefix.
    // AB/SB can become law; ACA/SCA are constitutional amendments that can
    // land on the ballot; ACR/SCR/AJR/SJR are resolutions; HR/SR are
    // single-chamber housekeeping.
    var measureKind: String {
        let prefix = code.prefix(while: \.isLetter)
        switch prefix {
        case "AB", "SB": return "bill"
        case "ACA", "SCA": return "amendment"
        case "ACR", "SCR", "AJR", "SJR": return "resolution"
        case "HR", "SR": return "chamber res."
        default: return "bill"
        }
    }

    var isBill: Bool { measureKind == "bill" }
    var isLive: Bool { !["law", "vetoed", "enjoined", "dead"].contains(status) }
}

struct LegislationFile: Codable {
    let state: String
    let session: String
    let stages: [String]
    let bills: [Bill]

    var byId: [String: Bill] { Dictionary(bills.map { ($0.id, $0) }) { _, last in last } }
}

// MARK: - People — who holds the seats
// data/people/<state>.json = the roster (light, loads at once).
// data/people/<state>/<person-id>.json = one member's full vote history,
// loaded on demand when their profile opens — 600k rows can't decode at launch.

struct PersonVote: Hashable, Codable {
    let bill: String           // our bill id — joins LegislationFile
    let option: String         // yes | no | other
    let date: String
}

struct Legislator: Identifiable, Hashable, Codable {
    let id: String             // ocd-person/…
    let name: String
    let seat: String           // "State Senate · D-11"
    let chamber: String        // senate | assembly
    let district: String
    let party: String          // D | R | I | …
    var photo: String? = nil
    var email: String? = nil
    var site: String? = nil
    var authored: [String] = []
    var coauthored: [String] = []
    var voteCount = 0

    enum CodingKeys: String, CodingKey {
        case id, name, seat, chamber, district, party, photo, email, site,
             authored, coauthored, voteCount
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        seat = try c.decode(String.self, forKey: .seat)
        chamber = try c.decode(String.self, forKey: .chamber)
        district = try c.decode(String.self, forKey: .district)
        party = try c.decode(String.self, forKey: .party)
        photo = try c.decodeIfPresent(String.self, forKey: .photo)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        site = try c.decodeIfPresent(String.self, forKey: .site)
        authored = try c.decodeIfPresent([String].self, forKey: .authored) ?? []
        coauthored = try c.decodeIfPresent([String].self, forKey: .coauthored) ?? []
        voteCount = try c.decodeIfPresent(Int.self, forKey: .voteCount) ?? 0
    }
}

struct PeopleFile: Codable {
    let state: String
    let session: String
    let people: [Legislator]

    func find(_ id: String) -> Legislator? { people.first { $0.id == id } }
    func find(name: String) -> Legislator? {
        people.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
    func chamber(_ c: String) -> [Legislator] { people.filter { $0.chamber == c } }
}

enum Government {
    private static var cache: [String: JurisdictionFile] = [:]
    private static var activityCache: [String: ActivityFile] = [:]
    private static var legislationCache: [String: LegislationFile] = [:]
    private static var peopleCache: [String: PeopleFile] = [:]
    private static var votesCache: [String: [PersonVote]] = [:]

    // Bundled in data/jurisdictions/<state>.json — subdirectory lookup so all
    // 50 states can share one folder reference in the project.
    static func load(_ stateID: String) -> JurisdictionFile? {
        if let f = cache[stateID] { return f }
        let key = stateID.lowercased()
        guard let url = Bundle.main.url(forResource: key, withExtension: "json", subdirectory: "jurisdictions"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(JurisdictionFile.self, from: data)
        else { return nil }
        cache[stateID] = file
        return file
    }

    static func available(_ stateID: String) -> Bool { load(stateID) != nil }

    // Bundled in data/activity/<state>.json
    static func activity(_ stateID: String) -> ActivityFile? {
        if let f = activityCache[stateID] { return f }
        let key = stateID.lowercased()
        guard let url = Bundle.main.url(forResource: key, withExtension: "json", subdirectory: "activity"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ActivityFile.self, from: data)
        else { return nil }
        activityCache[stateID] = file
        return file
    }

    // Bundled in data/legislation/<state>.json
    static func legislation(_ stateID: String) -> LegislationFile? {
        if let f = legislationCache[stateID] { return f }
        let key = stateID.lowercased()
        guard let url = Bundle.main.url(forResource: key, withExtension: "json", subdirectory: "legislation"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(LegislationFile.self, from: data)
        else { return nil }
        legislationCache[stateID] = file
        return file
    }

    // Bundled in data/people/<state>.json — the roster.
    static func people(_ stateID: String) -> PeopleFile? {
        if let f = peopleCache[stateID] { return f }
        let key = stateID.lowercased()
        guard let url = Bundle.main.url(forResource: key, withExtension: "json", subdirectory: "people"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PeopleFile.self, from: data)
        else { return nil }
        peopleCache[stateID] = file
        return file
    }

    // Bundled in data/people/<state>/<short-id>.json — one member's roll calls.
    static func votes(for personID: String, in stateID: String) -> [PersonVote] {
        if let v = votesCache[personID] { return v }
        let short = String(personID.split(separator: "/").last ?? "")
        guard let url = Bundle.main.url(forResource: short, withExtension: "json",
                                        subdirectory: "people/\(stateID.lowercased())"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PersonVotesFile.self, from: data)
        else { return [] }
        votesCache[personID] = file.votes
        return file.votes
    }
}

private struct PersonVotesFile: Codable {
    let id: String
    let votes: [PersonVote]
}
