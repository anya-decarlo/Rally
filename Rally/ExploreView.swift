import SwiftUI

// 🧭 EXPLORE YOUR GOVERNMENT — the four levels, top to bottom. Pick a county,
// pick a city, and your stack assembles itself. Jurisdictions you can't reach
// aren't yours.
struct ExploreView: View {
    let place: Place
    let file: JurisdictionFile
    let onClose: () -> Void

    @State private var countyID: String?
    @State private var cityID: String?
    @State private var districtIDs = Set<String>()
    @State private var detail: Jurisdiction?
    @State private var showBills = false
    @State private var activeKind: ActivityKind?
    @State private var picking: JurisdictionKind?
    @State private var query = ""
    @State private var shown = false
    @AppStorage("stack") private var stackRaw = ""

    init(place: Place, onClose: @escaping () -> Void) {
        self.place = place
        self.file = Government.load(place.id)!
        self.onClose = onClose
    }

    private var county: Jurisdiction? { countyID.flatMap(file.find) }
    private var city: Jurisdiction? { cityID.flatMap(file.find) }
    private var unincorporated: Bool { county != nil && cityID == "__unincorporated" }
    private var activity: ActivityFile? { Government.activity(place.id) }

    private var stack: [Jurisdiction] {
        file.stack(county: countyID ?? "", city: unincorporated ? nil : cityID,
                   districts: Array(districtIDs))
    }

    // Every seat across your stack that someone gets elected to.
    private var seatsGoverningYou: Int {
        stack.flatMap(\.seats).filter { $0.elected != "retention" }.map(\.seats)
            .reduce(0, +)
    }

    var body: some View {
        ZStack {
            LavaLamp(seed: 7, speed: 0.3)
                .ignoresSafeArea()

            if let detail {
                JurisdictionView(jurisdiction: detail, file: file) {
                    withAnimation(.snappy(duration: 0.3)) { self.detail = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if showBills, let leg = Government.legislation(place.id) {
                LegislationView(place: place, file: leg) {
                    withAnimation(.snappy(duration: 0.3)) { showBills = false }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let kind = activeKind, let activity {
                ActivityKindView(kind: kind, activity: activity,
                                 onBills: { activeKind = nil; showBills = true }) {
                    withAnimation(.snappy(duration: 0.3)) { activeKind = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                main
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(Theme.bg)
        .onAppear { withAnimation(.bouncy(duration: 0.7)) { shown = true } }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let leg = Government.legislation(place.id), !leg.bills.isEmpty {
                        sessionBanner(leg)
                    }

                    ForEach(file.levels.compactMap(JurisdictionKind.init(rawValue:)), id: \.self) { kind in
                        levelSection(kind)
                    }

                    if let activity { trackerSection(activity) }

                    stackCard
                        .padding(.top, 8)

                    Text("Skeleton build. Seats are real; people and money are being loaded.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 22)
            }
            .opacity(shown ? 1 : 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button { onClose() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .black))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 8)

            Text(place.name)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Every level that can tax you, govern you, or get elected by you.")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Level sections

    private func levelSection(_ kind: JurisdictionKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(kind)

            switch kind {
            case .state:    AnyView(stateBody)
            case .county:   AnyView(countyBody)
            case .city:     AnyView(cityBody)
            case .district: AnyView(districtBody)
            }
        }
    }

    private func sectionHeader(_ kind: JurisdictionKind) -> some View {
        let meta = file.levelsMeta?.first { $0.kind == kind.rawValue }
        return VStack(alignment: .leading, spacing: 3) {
            Text(meta?.label ?? kind.label)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(levelColor(kind))
            Text(meta?.tagline ?? kind.tagline)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
        }
        .padding(.bottom, 8)
    }

    private func levelColor(_ kind: JurisdictionKind) -> Color {
        switch kind {
        case .state: Theme.cyan
        case .county: Theme.pink
        case .city: Theme.lime
        case .district: Theme.violet
        }
    }

    private var stateBody: some View {
        Group {
            if let s = file.stateJurisdiction {
                jurisdictionRow(s, color: Theme.cyan)
            }
        }
    }

    @ViewBuilder
    private var countyBody: some View {
        if let county {
            jurisdictionRow(county, color: Theme.pink) {
                smallAction("change") { picking = .county; query = "" }
            }
        } else {
            pickButton("Pick your county — 58 of them", kind: .county, color: Theme.pink)
        }
        if picking == .county { pickerList(file.kind(.county), kind: .county) }
    }

    @ViewBuilder
    private var cityBody: some View {
        if county == nil {
            lockedRow("Pick a county first")
        } else if let city {
            jurisdictionRow(city, color: Theme.lime) {
                smallAction("change") { picking = .city; query = "" }
            }
        } else if unincorporated {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unincorporated \(county!.name)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("The county is your city government.")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                Spacer()
                smallAction("change") { picking = .city; query = "" }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.lime.opacity(0.4), lineWidth: 1))
        } else {
            pickButton("Pick your city, or skip if unincorporated", kind: .city, color: Theme.lime)
        }
        if picking == .city {
            let cities = file.children(of: countyID ?? "")
            pickerList(cities, kind: .city, unincorporatedOption: true)
        }
    }

    private var districtBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(file.districtCatalog, id: \.kind) { k in
                HStack(spacing: 10) {
                    Text(k.kind.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Theme.violet)
                        .frame(width: 130, alignment: .leading)
                    Text(k.count)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if let note = k.note {
                        Text(note)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                            .lineLimit(1)
                    }
                }
            }
            ForEach(file.kind(.district)) { d in
                jurisdictionRow(d, color: Theme.violet) {
                    Button {
                        Haptic.tick()
                        withAnimation(.snappy) {
                            if districtIDs.contains(d.id) { districtIDs.remove(d.id) }
                            else { districtIDs.insert(d.id) }
                        }
                    } label: {
                        Image(systemName: districtIDs.contains(d.id) ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(districtIDs.contains(d.id) ? Theme.lime : Theme.violet)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("We can't tell which districts cover you without your address — that lookup is next. For now, add the ones you know.")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim.opacity(0.7))
                .padding(.top, 2)
        }
    }

    // MARK: - Rows

    private func jurisdictionRow(_ j: Jurisdiction, color: Color) -> some View {
        jurisdictionRow(j, color: color) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(color)
        }
    }

    private func jurisdictionRow<Trailing: View>(_ j: Jurisdiction, color: Color,
                                                 @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptic.tap()
                withAnimation(.snappy(duration: 0.3)) { detail = j }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(j.name)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(j.seatSummary)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .lineLimit(2)
                }
            }
            .buttonStyle(.plain)

            trailing()
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.35), lineWidth: 1))
    }

    private func pickButton(_ label: String, kind: JurisdictionKind, color: Color) -> some View {
        Button {
            Haptic.tap()
            withAnimation(.snappy) { picking = picking == kind ? nil : kind }
            query = ""
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: picking == kind ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(color)
            }
            .padding(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
        }
        .buttonStyle(.plain)
    }

    private func lockedRow(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.dim.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
    }

    private func smallAction(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tick()
            withAnimation(.snappy) { action() }
        } label: {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Theme.dim)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.edge, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func pickerList(_ items: [Jurisdiction], kind: JurisdictionKind,
                            unincorporatedOption: Bool = false) -> some View {
        let filtered = query.isEmpty ? items
            : items.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return VStack(spacing: 0) {
            TextField("filter…", text: $query)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .padding(10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 4)

            if unincorporatedOption {
                pickRow("Unincorporated — no city", selected: unincorporated) {
                    cityID = "__unincorporated"; picking = nil
                }
            }
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { j in
                        pickRow(j.name, selected: selectedID(kind) == j.id) {
                            select(j, kind: kind)
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(10)
        .background(Theme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.edge, lineWidth: 1))
        .padding(.top, 6)
    }

    private func pickRow(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tick()
            action()
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: selected ? .black : .medium, design: .rounded))
                    .foregroundStyle(selected ? Theme.lime : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected { Image(systemName: "checkmark").foregroundStyle(Theme.lime) }
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func selectedID(_ kind: JurisdictionKind) -> String? {
        kind == .county ? countyID : cityID
    }

    private func select(_ j: Jurisdiction, kind: JurisdictionKind) {
        switch kind {
        case .county: countyID = j.id; cityID = nil
        case .city: cityID = j.id
        default: break
        }
        withAnimation(.snappy) { picking = nil }
    }

    // MARK: - Session banner → the legislation feed

    private func sessionBanner(_ leg: LegislationFile) -> some View {
        Button {
            Haptic.tap()
            withAnimation(.snappy(duration: 0.3)) { showBills = true }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📜 SACRAMENTO IS IN SESSION")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.orange)
                    Text("\(leg.bills.count) bills on the wire — every card is a bill,\nevery bill has its people.")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.orange.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(SquishButton())
    }

    // MARK: - Between-elections tracker

    private func trackerSection(_ activity: ActivityFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BETWEEN ELECTIONS")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Theme.orange)
            Text("Government happens all year. November is just the check-in.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)

            explainerCard(activity.explainer)

            // The taxonomy — the twelve lanes of the stream. Tap one: if it's
            // wired, you get the feed; if not, it says who's feeding it next.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(activity.activityKinds, id: \.kind) { k in
                    let count = activity.items.filter { $0.kind == k.kind }.count
                    Button {
                        Haptic.tick()
                        withAnimation(.snappy(duration: 0.3)) { activeKind = k }
                    } label: {
                        HStack(spacing: 10) {
                            Text(k.label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 150, alignment: .leading)
                            Text(k.example)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.dim)
                                .lineLimit(1)
                            Spacer()
                            Text(count > 0 ? "\(count)" : "soon")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(count > 0 ? Theme.lime : Theme.dim.opacity(0.5))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Theme.dim.opacity(0.5))
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    if k.kind != activity.activityKinds.last?.kind {
                        Divider().overlay(Theme.edge.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.edge, lineWidth: 1))
        }
        .padding(.top, 12)
    }

    private func explainerCard(_ explainer: Explainer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW A LAW IS MADE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Theme.orange)
            Text(explainer.topic)
                .font(.system(size: 17, weight: .black, design: .serif))
                .foregroundStyle(.white)

            ForEach(explainer.paths, id: \.id) { path in
                VStack(alignment: .leading, spacing: 8) {
                    Text(path.label)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(path.jurisdiction == "us" ? Theme.cyan : Theme.pink)
                    ForEach(Array(path.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.bg)
                                .frame(width: 18, height: 18)
                                .background(path.jurisdiction == "us" ? Theme.cyan : Theme.pink,
                                            in: Circle())
                            Text(step)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(12)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }

            Text(explainer.note)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.orange.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Stack

    private var stackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR STACK")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Theme.yellow)

            if stack.count <= 1 {
                Text("Pick a county and city above — your ballot is everything in the stack.")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            } else {
                ForEach(stack) { j in
                    HStack(spacing: 10) {
                        Text(j.kind.label.prefix(1))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.bg)
                            .frame(width: 18, height: 18)
                            .background(levelColor(j.kind), in: RoundedRectangle(cornerRadius: 5))
                        Text(j.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(j.kind.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Theme.dim)
                    }
                }

                if seatsGoverningYou > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("≈\(seatsGoverningYou)")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.yellow)
                        Text("elected offices govern you — every contest\nand decision in them is yours.")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                    }
                    .padding(.top, 4)
                }

                Button {
                    Haptic.tap()
                    stackRaw = stack.map(\.id).joined(separator: ",")
                } label: {
                    Text("THIS IS MY BALLOT →")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(SquishButton())
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.yellow.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Jurisdiction detail

struct JurisdictionView: View {
    let jurisdiction: Jurisdiction
    let file: JurisdictionFile
    let onBack: () -> Void

    @State private var roster: String?      // chamber being browsed
    @State private var person: Legislator?

    private var children: [Jurisdiction] { file.children(of: jurisdiction.id) }
    private var rosterFile: PeopleFile? { Government.people(file.state) }
    private var billIndex: [String: Bill] {
        Government.legislation(file.state)?.byId ?? [:]
    }

    var body: some View {
        ZStack {
            if let person {
                LegislatorProfileView(person: person, bills: billIndex,
                                      state: file.state) {
                    withAnimation(.snappy(duration: 0.3)) { self.person = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let roster, let rosterFile {
                RosterView(chamber: roster, people: rosterFile.chamber(roster),
                           onPick: { p in
                               withAnimation(.snappy(duration: 0.3)) { person = p }
                           }) {
                    withAnimation(.snappy(duration: 0.3)) { self.roster = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                detail
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .black))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(jurisdiction.kind.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(jurisdiction.name)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        if let covers = jurisdiction.covers {
                            Text("covers \(covers)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.dim)
                        }
                    }

                    seatsSection
                    childrenSection
                    electionsSection
                    representativesSection
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
    }

    private func blockHeader(_ text: String, _ color: Color = Theme.cyan) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .tracking(2)
            .foregroundStyle(color)
    }

    // Chambers with a live roster become doors — tap "State Senate" →
    // the 40 humans holding those seats.
    private func rosterFor(_ s: Seat) -> String? {
        guard jurisdiction.kind == .state, rosterFile != nil else { return nil }
        switch s.office {
        case "State Senate": return "senate"
        case "State Assembly": return "assembly"
        default: return nil
        }
    }

    private var seatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            blockHeader("THE SEATS")
            ForEach(jurisdiction.seats, id: \.office) { s in
                let chamber = rosterFor(s)
                Button {
                    if let chamber {
                        Haptic.tick()
                        withAnimation(.snappy(duration: 0.3)) { roster = chamber }
                    }
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.office)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            if let note = s.note {
                                Text(note)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.dim)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if s.seats > 0 {
                                Text("\(s.seats)")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(chamber != nil ? Theme.violet : Theme.cyan)
                            }
                            if !s.elected.isEmpty {
                                Text(s.elected.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(Theme.dim)
                            }
                        }
                        if chamber != nil {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Theme.violet)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(chamber == nil)
                if s.office != jurisdiction.seats.last?.office {
                    Divider().overlay(Theme.edge)
                }
            }
        }
    }

    @ViewBuilder
    private var childrenSection: some View {
        if !children.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                blockHeader(jurisdiction.kind == .state ? "COUNTIES" : "CITIES",
                            Theme.pink)
                Text("\(children.count)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                + Text("  inside \(jurisdiction.name)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
        }
    }

    private var electionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            blockHeader("ELECTIONS", Theme.lime)
            Text("No contests loaded yet — filings get parsed in as they're published.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
        }
    }

    private var representativesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            blockHeader("REPRESENTATIVES", Theme.violet)
            Text("Who holds these seats right now — rosters load from official sources next.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
        }
    }
}

// MARK: - One lane of the stream — a single activity kind, filtered

struct ActivityKindView: View {
    let kind: ActivityKind
    let activity: ActivityFile
    let onBills: () -> Void
    let onBack: () -> Void

    private var items: [ActivityItem] { activity.items.filter { $0.kind == kind.kind } }

    // Which collector feeds this lane
    private var feed: String {
        switch kind.kind {
        case "billIntroduced", "committeeHearing", "vote":
            "CA Legislative Information + Digital Democracy"
        case "initiative", "qualifiedMeasure": "CA Secretary of State"
        case "executiveOrder": "Governor's office + Federal Register"
        case "regulation": "Federal Register + CA agencies"
        case "courtRuling": "CA Judicial Branch + CourtListener"
        case "lawsuit": "California DOJ"
        case "publicHearing": "Legislative calendars + county/city agendas"
        case "appointment": "Governor + Senate confirmations"
        case "budget": "Dept. of Finance + LAO"
        default: "official sources"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .black))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(kind.kind.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.label)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("e.g. \(kind.example)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                    }

                    if kind.kind == "billIntroduced" {
                        Button {
                            Haptic.tap()
                            onBills()
                        } label: {
                            HStack {
                                Text("OPEN THE LEGISLATURE FEED →")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .tracking(1)
                                    .foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Theme.orange, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .buttonStyle(SquishButton())
                    }

                    if items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(items.count) ON THE WIRE")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.dim)
                            Text("Nothing filed yet — this lane's collector hasn't shipped. When it does, it pulls from:")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.dim)
                            Text(feed)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.orange)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.edge, lineWidth: 1))
                    } else {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(item.date)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.dim)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    ExploreView(place: Place.all.first { $0.id == "CA" }!) { }
}
