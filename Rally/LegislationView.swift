import SwiftUI

// 📜 IN SESSION — every bill moving through the legislature, as a feed.
// Doesn't matter where you live: an AB affects everyone in the state.
// Every card = one bill + the people who wrote it and vote on it.
struct LegislationView: View {
    let place: Place
    let file: LegislationFile
    let onBack: () -> Void

    @AppStorage("following") private var followingRaw = ""
    @State private var typeFilter = "all"
    @State private var statusFilter = "all"

    private var following: Set<String> {
        Set(followingRaw.split(separator: ",").map(String.init))
    }

    private var filtered: [Bill] {
        file.bills.filter { b in
            (typeFilter == "all" || b.measureKind == typeFilter) &&
            (statusFilter == "all"
             || (statusFilter == "live" && b.isLive)
             || (statusFilter == "law" && b.status == "law")
             || (statusFilter == "vetoed" && b.status == "vetoed")
             || (statusFilter == "dead" && (b.status == "dead" || b.status == "enjoined")))
        }
    }

    private var followedBills: [Bill] { filtered.filter { following.contains($0.id) } }
    private var otherBills: [Bill] { filtered.filter { !following.contains($0.id) } }

    private func toggle(_ bill: Bill) {
        var set = following
        if set.contains(bill.id) { set.remove(bill.id) } else { set.insert(bill.id) }
        followingRaw = set.sorted().joined(separator: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    if !followedBills.isEmpty {
                        Text("FOLLOWING")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(Theme.lime)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(followedBills) { billCard($0) }
                    }
                    ForEach(otherBills) { billCard($0) }

                    Text("Every card is a real bill. Tap the receipt — it opens the official record.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                Sticker("📜 in session", color: Theme.orange)
                    .rotationEffect(.degrees(2))
            }
            .padding(.top, 8)

            Text("\(place.name) Legislature")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("\(file.session) · \(filtered.count)/\(file.bills.count) on the wire")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)

            filterRow(["all", "bill", "amendment", "resolution"], selected: $typeFilter) { f in
                f == "all" ? "ALL" : f.uppercased() + "S"
            }
            filterRow(["all", "live", "law", "vetoed", "dead"], selected: $statusFilter) { f in
                f == "live" ? "IN PLAY" : f.uppercased()
            }
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 22)
    }

    private func filterRow(_ options: [String], selected: Binding<String>,
                           label: @escaping (String) -> String) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { f in
                Button {
                    Haptic.tick()
                    withAnimation(.snappy(duration: 0.2)) { selected.wrappedValue = f }
                } label: {
                    Text(label(f))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(selected.wrappedValue == f ? Theme.bg : Theme.dim)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(selected.wrappedValue == f ? Theme.orange : .clear,
                                    in: Capsule())
                        .overlay(Capsule().stroke(selected.wrappedValue == f ? .clear : Theme.edge,
                                                  lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - The card

    private func billCard(_ bill: Bill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(bill.code)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(chamberColor(bill), in: RoundedRectangle(cornerRadius: 6))
                statusSticker(bill)
                if bill.measureKind != "bill" {
                    Text(bill.measureKind.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(bill.measureKind == "amendment" ? Theme.yellow : Theme.dim)
                }
                if bill.crossLevel {
                    Text("⚔️ STATE↔FED")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Theme.yellow)
                }
                Spacer()
                Button {
                    Haptic.tick()
                    withAnimation(.snappy) { toggle(bill) }
                } label: {
                    Image(systemName: following.contains(bill.id) ? "bell.fill" : "bell")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(following.contains(bill.id) ? Theme.lime : Theme.dim)
                }
                .buttonStyle(.plain)
            }

            Text(bill.title)
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text(bill.summary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))

            progressRail(bill)

            if !bill.people.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WHO'S ON IT")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Theme.dim)
                    ForEach(bill.people, id: \.name) { p in
                        HStack(spacing: 8) {
                            Text(p.role.uppercased())
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(p.role.contains("author") && !p.role.contains("co")
                                                 ? chamberColor(bill) : Theme.dim)
                                .frame(width: 92, alignment: .leading)
                            Text(p.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(p.seat)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.dim)
                        }
                    }
                }
            }

            if let last = bill.lastAction {
                HStack(spacing: 8) {
                    Text(last.date)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                    Text(last.action)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .lineLimit(2)
                    Spacer()
                    if let url = URL(string: bill.source) {
                        Link(destination: url) {
                            Text("RECEIPT ↗")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(chamberColor(bill))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(chamberColor(bill).opacity(0.5), lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(statusColor(bill).opacity(0.35), lineWidth: 1))
    }

    // MARK: - Bits

    private func chamberColor(_ bill: Bill) -> Color {
        bill.chamber == "senate" ? Theme.pink : Theme.cyan
    }

    private func statusColor(_ bill: Bill) -> Color {
        switch bill.status {
        case "law": Theme.lime
        case "vetoed": Theme.orange
        case "enjoined": Theme.violet
        default: Theme.cyan
        }
    }

    private func statusSticker(_ bill: Bill) -> some View {
        Text(bill.status.uppercased())
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(statusColor(bill))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(statusColor(bill).opacity(0.7), lineWidth: 1))
    }

    private func progressRail(_ bill: Bill) -> some View {
        let dead = ["vetoed", "enjoined", "dead"].contains(bill.status)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                ForEach(0..<file.stages.count, id: \.self) { i in
                    Capsule()
                        .fill(i < bill.stage ? statusColor(bill) : .white.opacity(0.12))
                        .frame(height: 4)
                }
            }
            HStack {
                Text(file.stages[min(bill.stage, file.stages.count - 1)].uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(statusColor(bill))
                Spacer()
                if dead {
                    Text(bill.status == "vetoed" ? "☠ died at the governor's desk"
                         : bill.status == "enjoined" ? "⚖️ tied up in federal court" : "")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(statusColor(bill))
                }
            }
        }
    }
}

#Preview {
    LegislationView(place: Place.all.first { $0.id == "CA" }!,
                    file: Government.legislation("CA")!) { }
}
