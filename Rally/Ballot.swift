import Foundation

// DC General Election, November 2026. As listed. Update here when the ballot changes.

enum Ballot {
    static let contests: [Contest] = [
        // FEDERAL
        Contest(group: .federal, office: "U.S. House Delegate", candidates: [
            Candidate(name: "Robert White", party: .democrat),
            Candidate(name: "Denise Rosado", party: .republican),
            Candidate(name: "Kymone Freeman", party: .green),
            Candidate(name: "Rebekkah Green", party: .independent, writeIn: true),
            Candidate(name: "David Solana", party: .independent, writeIn: true),
        ]),
        Contest(group: .federal, office: "U.S. Shadow Senator", candidates: [
            Candidate(name: "Paul Strauss", party: .democrat, incumbent: true),
            Candidate(name: "Rob Simmons", party: .republican),
        ]),
        Contest(group: .federal, office: "U.S. Shadow Representative", candidates: [
            Candidate(name: "Franklin Garcia", party: .democrat),
            Candidate(name: "Ciprian Ivanof", party: .republican),
        ]),

        // DISTRICT-WIDE
        Contest(group: .districtWide, office: "Mayor", candidates: [
            Candidate(name: "Janeese Lewis George", party: .democrat),
            Candidate(name: "Robert L. Gross", party: .green),
            Candidate(name: "Rhonda Hamilton", party: .independent),
        ]),
        Contest(group: .districtWide, office: "Attorney General", candidates: [
            Candidate(name: "Brian Schwalb", party: .democrat, incumbent: true),
            Candidate(name: "Manuel Rivera", party: .republican),
        ]),
        Contest(group: .districtWide, office: "Council Chairman", candidates: [
            Candidate(name: "Phil Mendelson", party: .democrat, incumbent: true),
            Candidate(name: "Abi-Ananiah Prudent", party: .republican),
            Candidate(name: "John C. Cheeks", party: .independent, writeIn: true),
        ]),
        Contest(group: .districtWide, office: "Council At-Large", candidates: [
            Candidate(name: "Elissa Silverman", party: .independent, incumbent: true),
            Candidate(name: "Oye Owolewa", party: .democrat),
            Candidate(name: "Darrell Green", party: .republican),
            Candidate(name: "Darryl Moch", party: .green),
            Candidate(name: "Joe Jackson", party: .independent, writeIn: true),
        ]),

        // WARD
        Contest(group: .ward, office: "Councilmember — Ward 1", candidates: [
            Candidate(name: "Aparna Raj", party: .democrat),
            Candidate(name: "Jett Jasper", party: .republican),
            Candidate(name: "Jude Crannitch", party: .green),
            Candidate(name: "Ryan Prince", party: .independent),
        ]),
        Contest(group: .ward, office: "Councilmember — Ward 3", candidates: [
            Candidate(name: "Matthew Frumin", party: .democrat, incumbent: true),
        ]),
        Contest(group: .ward, office: "Councilmember — Ward 5", candidates: [
            Candidate(name: "Zachary Parker", party: .democrat, incumbent: true),
            Candidate(name: "Jeffrey Kihien-Palza", party: .republican),
            Candidate(name: "Joyce Robinson-Paul", party: .green),
        ]),
        Contest(group: .ward, office: "Councilmember — Ward 6", candidates: [
            Candidate(name: "Charles Allen", party: .democrat, incumbent: true),
            Candidate(name: "Jorge Rice", party: .republican),
        ]),

        // EDUCATION
        Contest(group: .education, office: "State Board of Education — Ward 1", candidates: [
            Candidate(name: "Ben Williams", party: .nonpartisan, incumbent: true),
        ]),
        Contest(group: .education, office: "State Board of Education — Ward 3", candidates: [
            Candidate(name: "Eric Goulet", party: .nonpartisan, incumbent: true),
            Candidate(name: "Aaron Wesolowski", party: .nonpartisan),
        ]),
        Contest(group: .education, office: "State Board of Education — Ward 5", candidates: [
            Candidate(name: "Jon Alfuth", party: .nonpartisan),
        ]),
        Contest(group: .education, office: "State Board of Education — Ward 6", candidates: [
            Candidate(name: "Lynn Jennings", party: .nonpartisan),
            Candidate(name: "David Parker", party: .nonpartisan),
            Candidate(name: "Joshua Wiley", party: .nonpartisan),
            Candidate(name: "Amber Williams", party: .nonpartisan),
        ]),

        // NEIGHBORHOOD
        Contest(group: .neighborhood, office: "Advisory Neighborhood Commissioner", candidates: [],
                note: "Your ANC and single-member district depend on your address."),

        // BALLOT MEASURES
        Contest(group: .ballotMeasures, office: "Initiative 86", candidates: []),
    ]

    static func contests(in group: ContestGroup) -> [Contest] {
        contests.filter { $0.group == group }
    }
}
