import SwiftUI

// The FYP. One stream for EVERYTHING — posts, receipts, facts now;
// clips, games ("who wore it better"), and anything else drop in as new cases.
// Every item knows its candidate; the feed is the product, candidates are context.
enum FYPItem: Identifiable {
    case post(Post, Candidate)
    case fact(Fact, Candidate)
    case faceoff(Faceoff)

    var id: String {
        // Same format as FeedItem so wallet dedup holds across both feeds.
        switch self {
        case .post(let p, _): p.id
        case .fact(let f, _): "fact:" + f.id
        case .faceoff(let f): "faceoff:" + f.id
        }
    }
    var candidate: Candidate? {
        switch self { case .post(_, let c), .fact(_, let c): c; case .faceoff: nil }
    }
    var category: String {
        switch self {
        case .post: "post"
        case .fact(let f, _): f.category ?? "bio"
        case .faceoff: "game"
        }
    }

    // One stream across the whole ballot: posts round-robin between candidates so
    // nobody hogs it, cards drop in every N items, taste-weighted per candidate.
    static func build(place: Place, store: PostStore, extras: ExtrasStore, fashion: FashionStore, taste: Taste, every n: Int = FeedItem.factEvery) -> [FYPItem] {
        let candidates = Ballot.contests(for: place).flatMap(\.candidates)
        var cards = candidates
            .flatMap { c in
                extras.facts(for: c).map {
                    (f: $0, c: c, k: Double.random(in: 0...1) * taste.weight(c.name, $0.category ?? "bio"))
                }
            }
            .sorted { $0.k > $1.k }
            .map { ($0.f, $0.c) }
            .makeIterator()
        var queues = candidates.compactMap { c -> (Candidate, [Post])? in
            let ps = store.posts(for: c).shuffled()
            return ps.isEmpty ? nil : (c, ps)
        }
        var out: [FYPItem] = []
        var sinceCard = 0, lastName = ""
        while !queues.isEmpty {
            var i = queues.indices.randomElement()!
            if queues.count > 1 && queues[i].0.name == lastName,
               let alt = queues.indices.first(where: { queues[$0].0.name != lastName }) { i = alt }
            let c = queues[i].0
            out.append(.post(queues[i].1.removeFirst(), c))
            lastName = c.name
            if queues[i].1.isEmpty { queues.remove(at: i) }
            sinceCard += 1
            if sinceCard >= n, let (f, fc) = cards.next() { out.append(.fact(f, fc)); sinceCard = 0 }
        }
        // Cards for candidates with no posts still get in — scattered, not dumped at the end.
        while let (f, fc) = cards.next() { out.insert(.fact(f, fc), at: Int.random(in: 0...out.count)) }
        // Games go near the top — you should hit one within a few swipes.
        for f in fashion.faceoffs.reversed() {
            out.insert(.faceoff(f), at: min(3, out.count))
        }
        return out
    }
}

struct ForYouView: View {
    let place: Place
    let onChangePlace: () -> Void
    @Environment(PostStore.self) private var store
    @Environment(ExtrasStore.self) private var extras
    @Environment(FashionStore.self) private var fashion
    @Environment(Taste.self) private var taste
    @Environment(Wallet.self) private var wallet
    @State private var items: [FYPItem] = []
    @State private var current: String?
    @State private var showBallot = false
    @State private var showPlay = false
    @State private var peek: Candidate?

    private var index: Int { items.firstIndex { $0.id == current } ?? 0 }
    private var offices: [String: String] {
        Dictionary(Ballot.contests(for: place).flatMap { c in c.candidates.map { ($0.name, c.office) } },
                   uniquingKeysWith: { a, _ in a })
    }

    private func rebuild() {
        items = FYPItem.build(place: place, store: store, extras: extras, fashion: fashion, taste: taste)
        if current == nil || !items.contains(where: { $0.id == current }) { current = items.first?.id }
    }

    private func judge(_ item: FYPItem, liked: Bool) {
        let name = item.candidate?.name ?? "fyp"
        taste.record(name, item.category, liked: liked)
        if liked { wallet.pocket(item) }
        Backend.signal(cardID: item.id, candidate: name, category: item.category, liked: liked)
        if let i = items.firstIndex(where: { $0.id == item.id }), i + 1 < items.count {
            withAnimation(.snappy(duration: 0.35)) { current = items[i + 1].id }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            LavaLamp(seed: Double(index) * 0.7 + 3)
                .ignoresSafeArea()

            if items.isEmpty {
                EmptyStage(text: "Receipts are loading in.\nSwipe up when they get here.", color: Theme.cyan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            Group {
                                switch item {
                                case .post(let p, let c):
                                    PostPage(post: p, color: Theme.party(c.party))
                                case .fact(let f, let c):
                                    switch f.category ?? "bio" {
                                    case "bio": FactPage(fact: f, candidate: c)
                                    case "pair": PairPage(fact: f, candidate: c)
                                    default: ReceiptPage(fact: f, candidate: c)
                                    }
                                case .faceoff(let f):
                                    FaceoffPage(faceoff: f)
                                }
                            }
                            .swipeToJudge { liked in judge(item, liked: liked) }
                            .containerRelativeFrame(.vertical)
                            .overlay(alignment: .topLeading) {
                                if let c = item.candidate {
                                    CandidateTag(candidate: c, office: offices[c.name] ?? "") {
                                        Haptic.tick()
                                        peek = c
                                    }
                                    .padding(.top, 116)
                                    .padding(.leading, 16)
                                }
                            }
                            .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $current)
                .onChange(of: current) { Haptic.tick() }
                .ignoresSafeArea()
            }

            // header: where you vote · the feed · your ballot · your wallet
            HStack(spacing: 10) {
                Button {
                    Haptic.tick()
                    onChangePlace()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                        Text(place.id)
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    Haptic.tap()
                    showPlay = true
                } label: {
                    HStack(spacing: 6) {
                        Text("🎲")
                        Text("PLAY")
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Theme.pink.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button {
                    Haptic.tap()
                    showBallot = true
                } label: {
                    HStack(spacing: 6) {
                        Text("🗳️")
                        Text("BALLOT")
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Theme.yellow.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
                WalletButton()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Theme.bg)
        .fullScreenCoverCompat(isPresented: $showBallot) {
            StoriesView(place: place, onClose: { showBallot = false }) {
                showBallot = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onChangePlace() }
            }
        }
        .sheet(isPresented: $showPlay) {
            PlayView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
                .presentationCornerRadius(32)
        }
        .sheet(item: $peek) { c in
            CandidateView(candidate: c)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.card)
                .presentationCornerRadius(32)
        }
        .onAppear { rebuild() }
        .onChange(of: store.posts) { rebuild() }
        .onChange(of: extras.extras.mapValues { $0.facts.count }) { rebuild() }
    }
}

// Who this card is about — tap for their profile. Mixed feeds need this or it's chaos soup.
struct CandidateTag: View {
    let candidate: Candidate
    let office: String
    let onTap: () -> Void
    private var color: Color { Theme.party(candidate.party) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 7, height: 7)
                    .shadow(color: color, radius: 5)
                Text(candidate.name)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                if !office.isEmpty {
                    Text(office.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
