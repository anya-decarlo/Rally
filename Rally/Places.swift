import Foundation

// Where you vote. One place → one ballot → everything downstream.

struct Place: Identifiable, Hashable {
    let id: String        // USPS code
    let name: String
    var live = false      // we have a ballot for it

    static let all: [Place] = [
        Place(id: "DC", name: "Washington, DC", live: true),
        Place(id: "AL", name: "Alabama"), Place(id: "AK", name: "Alaska"),
        Place(id: "AZ", name: "Arizona"), Place(id: "AR", name: "Arkansas"),
        Place(id: "CA", name: "California"), Place(id: "CO", name: "Colorado"),
        Place(id: "CT", name: "Connecticut"), Place(id: "DE", name: "Delaware"),
        Place(id: "FL", name: "Florida"), Place(id: "GA", name: "Georgia"),
        Place(id: "HI", name: "Hawaii"), Place(id: "ID", name: "Idaho"),
        Place(id: "IL", name: "Illinois"), Place(id: "IN", name: "Indiana"),
        Place(id: "IA", name: "Iowa"), Place(id: "KS", name: "Kansas"),
        Place(id: "KY", name: "Kentucky"), Place(id: "LA", name: "Louisiana"),
        Place(id: "ME", name: "Maine"), Place(id: "MD", name: "Maryland"),
        Place(id: "MA", name: "Massachusetts"), Place(id: "MI", name: "Michigan"),
        Place(id: "MN", name: "Minnesota"), Place(id: "MS", name: "Mississippi"),
        Place(id: "MO", name: "Missouri"), Place(id: "MT", name: "Montana"),
        Place(id: "NE", name: "Nebraska"), Place(id: "NV", name: "Nevada"),
        Place(id: "NH", name: "New Hampshire"), Place(id: "NJ", name: "New Jersey"),
        Place(id: "NM", name: "New Mexico"), Place(id: "NY", name: "New York"),
        Place(id: "NC", name: "North Carolina"), Place(id: "ND", name: "North Dakota"),
        Place(id: "OH", name: "Ohio"), Place(id: "OK", name: "Oklahoma"),
        Place(id: "OR", name: "Oregon"), Place(id: "PA", name: "Pennsylvania"),
        Place(id: "RI", name: "Rhode Island"), Place(id: "SC", name: "South Carolina"),
        Place(id: "SD", name: "South Dakota"), Place(id: "TN", name: "Tennessee"),
        Place(id: "TX", name: "Texas"), Place(id: "UT", name: "Utah"),
        Place(id: "VT", name: "Vermont"), Place(id: "VA", name: "Virginia"),
        Place(id: "WA", name: "Washington"), Place(id: "WV", name: "West Virginia"),
        Place(id: "WI", name: "Wisconsin"), Place(id: "WY", name: "Wyoming"),
        Place(id: "PR", name: "Puerto Rico"), Place(id: "GU", name: "Guam"),
        Place(id: "VI", name: "U.S. Virgin Islands"), Place(id: "AS", name: "American Samoa"),
        Place(id: "MP", name: "Northern Mariana Islands"),
    ]

    static func find(_ id: String) -> Place? { all.first { $0.id == id } }
}

extension Ballot {
    static func contests(for place: Place) -> [Contest] {
        place.id == "DC" ? contests : []
    }
}
