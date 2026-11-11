import SwiftUI

// 👥 THE ROSTER — who holds a chamber's seats right now.
// Tap "State Senate" on the state card → 40 humans. Tap a human →
// everything they've authored, coauthored, and voted on. Receipts.
struct RosterView: View {
    let chamber: String          // senate | assembly
    let people: [Legislator]
    let onPick: (Legislator) -> Void
    let onBack: () -> Void

    private var title: String {
        chamber == "senate" ? "State Senate" : "State Assembly"
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
                Sticker("👥 roster", color: Theme.violet)
                    .rotationEffect(.degrees(2))
            }
            .padding(.top, 8)

            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("\(people.count) members · tap one — every bill and vote is theirs")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(people) { p in
                        Button {
                            Haptic.tick()
                            onPick(p)
                        } label: {
                            HStack(spacing: 12) {
                                Text(p.party)
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundStyle(Theme.bg)
                                    .frame(width: 26, height: 26)
                                    .background(partyColor(p), in: RoundedRectangle(cornerRadius: 7))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("District \(p.district) · \(p.authored.count) authored · \(p.voteCount) votes cast")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Theme.dim)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(Theme.dim)
                            }
                            .padding(12)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.edge, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .padding(.horizontal, 22)
    }

    static func partyColor(_ p: Legislator) -> Color {
        p.party == "D" ? Theme.cyan : p.party == "R" ? Theme.pink : Theme.yellow
    }

    private func partyColor(_ p: Legislator) -> Color { Self.partyColor(p) }
}

// MARK: - One human — the profile everything flows through

struct LegislatorProfileView: View {
    let person: Legislator
    let bills: [String: Bill]
    let state: String
    let onBack: () -> Void

    @AppStorage("followingPeople") private var followingRaw = ""
    @State private var votes: [PersonVote] = []
    @State private var tab = "authored"   // authored | coauthored | votes

    private var following: Set<String> {
        Set(followingRaw.split(separator: ",").map(String.init))
    }
    private var isFollowed: Bool { following.contains(person.id) }

    private func toggleFollow() {
        var set = following
        if isFollowed { set.remove(person.id) } else { set.insert(person.id) }
        followingRaw = set.sorted().joined(separator: ",")
    }

    private var chamberColor: Color {
        person.chamber == "senate" ? Theme.pink : Theme.cyan
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
                Button {
                    Haptic.tick()
                    withAnimation(.snappy) { toggleFollow() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isFollowed ? "bell.fill" : "bell")
                        Text(isFollowed ? "FOLLOWING" : "FOLLOW")
                            .tracking(1)
                    }
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(isFollowed ? Theme.bg : Theme.lime)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(isFollowed ? Theme.lime : .clear, in: Capsule())
                    .overlay(Capsule().stroke(Theme.lime, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)

            HStack(spacing: 14) {
                AsyncImage(url: URL(string: person.photo ?? "")) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Text(String(person.name.prefix(1)))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.bg)
                }
                .frame(width: 72, height: 72)
                .background(chamberColor.opacity(0.4))
                .clipShape(Circle())
                .overlay(Circle().stroke(chamberColor, lineWidth: 2))

                VStack(alignment: .leading, spacing: 5) {
                    Text(person.name)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(person.seat)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(chamberColor)
                }
                Spacer()
            }
            .padding(.top, 10)

            HStack(spacing: 16) {
                stat("\(person.authored.count)", "AUTHORED")
                stat("\(person.coauthored.count)", "COAUTHORED")
                stat("\(person.voteCount)", "VOTES CAST")
            }
            .padding(.top, 14)

            HStack(spacing: 6) {
                ForEach(["authored", "coauthored", "votes"], id: \.self) { t in
                    Button {
                        Haptic.tick()
                        withAnimation(.snappy(duration: 0.2)) { tab = t }
                    } label: {
                        Text(t.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(tab == t ? Theme.bg : Theme.dim)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(tab == t ? Theme.violet : .clear, in: Capsule())
                            .overlay(Capsule().stroke(tab == t ? .clear : Theme.edge,
                                                      lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    switch tab {
                    case "authored":    billList(person.authored)
                    case "coauthored":  billList(person.coauthored)
                    default:            voteList
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .padding(.horizontal, 22)
        .onAppear {
            if votes.isEmpty {
                votes = Government.votes(for: person.id, in: state)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Theme.dim)
        }
    }

    @ViewBuilder
    private func billList(_ ids: [String]) -> some View {
        let list = ids.compactMap { bills[$0] }
        if list.isEmpty {
            Text("none this session")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
        }
        ForEach(list) { bill in
            billRow(bill)
        }
    }

    private func billRow(_ bill: Bill) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(bill.code)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(bill.chamber == "senate" ? Theme.pink : Theme.cyan,
                            in: RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 3) {
                Text(bill.title)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(bill.status.uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(bill.status == "law" ? Theme.lime
                                         : bill.status == "vetoed" ? Theme.orange
                                         : Theme.cyan)
                    if let last = bill.lastAction {
                        Text(last.date)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                    }
                }
            }
            Spacer()
            if let url = URL(string: bill.source) {
                Link(destination: url) {
                    Text("↗")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.dim)
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.edge, lineWidth: 1))
    }

    private var voteList: some View {
        Group {
            if votes.isEmpty {
                Text("loading roll calls…")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
            ForEach(votes.prefix(200), id: \.self) { v in
                HStack(spacing: 10) {
                    Text(v.option.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(v.option == "yes" ? Theme.bg : Theme.orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(v.option == "yes" ? Theme.lime : .clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .stroke(v.option == "yes" ? .clear : Theme.orange,
                                    lineWidth: 1))
                    Text(bills[v.bill]?.code ?? v.bill)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(bills[v.bill]?.title ?? "")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.dim)
                        .lineLimit(1)
                    Spacer()
                    Text(v.date)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            }
            if votes.count > 200 {
                Text("+ \(votes.count - 200) more roll calls this session")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }
}
