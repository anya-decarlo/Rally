import SwiftUI

// A feed item is a post, or — every few swipes — a fun fact.
enum FeedItem: Identifiable {
    case post(Post), fact(Fact)
    var id: String {
        switch self { case .post(let p): p.id; case .fact(let f): "fact:" + f.id }
    }

    static let factEvery = 2   // a card after every N posts

    // Every N posts: alternate a fun fact (bio) and a receipt (money / vote / record).
    static func interleave(posts: [Post], facts: [Fact], every n: Int = factEvery) -> [FeedItem] {
        var out: [FeedItem] = []
        var bio = facts.filter { ($0.category ?? "bio") == "bio" }.shuffled().makeIterator()
        var receipts = facts.filter { $0.category != nil && $0.category != "bio" }.shuffled().makeIterator()
        var turn = 0
        for (i, p) in posts.enumerated() {
            out.append(.post(p))
            guard (i + 1) % n == 0 else { continue }
            let pick = turn % 2 == 0 ? (receipts.next() ?? bio.next()) : (bio.next() ?? receipts.next())
            if let pick { out.append(.fact(pick)) }
            turn += 1
        }
        return out
    }
}

// TikTok-vertical. One post per screen. Swipe up.
struct FeedView: View {
    let candidate: Candidate
    let posts: [Post]
    var facts: [Fact] = []
    @Environment(\.dismiss) private var dismiss
    @State private var current: String?
    @State private var items: [FeedItem] = []

    private var index: Int { items.firstIndex { $0.id == current } ?? 0 }

    var body: some View {
        ZStack(alignment: .top) {
            LavaLamp(seed: Double(index) * 0.7 + 11)
                .ignoresSafeArea()

            if posts.isEmpty {
                EmptyStage(text: "No posts loaded for \(candidate.name) yet.", color: Theme.party(candidate.party))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            Group {
                                switch item {
                                case .post(let post): PostPage(post: post, color: Theme.party(candidate.party))
                                case .fact(let fact):
                                    switch fact.category ?? "bio" {
                                    case "bio": FactPage(fact: fact, candidate: candidate)
                                    case "pair": PairPage(fact: fact, candidate: candidate)
                                    default: ReceiptPage(fact: fact, candidate: candidate)
                                    }
                                }
                            }
                            .containerRelativeFrame(.vertical)
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

            // header
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .black))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Text(candidate.name.uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                if !items.isEmpty {
                    Text("\(index + 1)/\(items.count)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Theme.bg)
        .onAppear {
            items = FeedItem.interleave(posts: posts, facts: facts)
            current = items.first?.id
        }
    }
}

// MARK: - ✨ Fun fact

struct FactPage: View {
    let fact: Fact
    let candidate: Candidate
    @Environment(\.openURL) private var openURL
    @State private var pop = false
    private var color: Color { Theme.party(candidate.party) }
    private static let emojis = ["✨", "🤯", "📚", "🫨", "👀", "💡", "🎉", "🧠"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Text(Self.emojis[abs(fact.text.hashValue) % Self.emojis.count])
                    .font(.system(size: 220))
                    .opacity(0.12)
                    .rotationEffect(.degrees(pop ? 8 : -8))
                    .offset(y: -geo.size.height * 0.12)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pop)

                VStack(alignment: .leading, spacing: 20) {
                    Spacer()
                    Sticker("wait, seriously?", color: Theme.yellow)
                        .rotationEffect(.degrees(-4))
                        .scaleEffect(pop ? 1 : 0.6)
                    // "wait, seriously?" facts have a punchline first sentence, then the story.
                    let (headline, story) = split(fact.text)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(headline)
                            .font(.system(size: headline.count < 60 ? 34 : 28, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.white, .white, Theme.yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: Theme.yellow.opacity(0.6), radius: 24)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        if !story.isEmpty {
                            Text(story)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineSpacing(3)
                                .minimumScaleFactor(0.8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .offset(y: pop ? 0 : 30)
                    .opacity(pop ? 1 : 0)
                    Button {
                        Haptic.tap()
                        openURL(fact.url)
                    } label: {
                        HStack(spacing: 6) {
                            Text(fact.source)
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.yellow, in: Capsule())
                        .shadow(color: Theme.yellow.opacity(0.7), radius: 12, y: 4)
                    }
                    .buttonStyle(SquishButton())
                    Spacer()
                }
                .padding(24)
            }
        }
        .onAppear { withAnimation(.bouncy(duration: 0.7)) { pop = true } }
        .onDisappear { pop = false }
    }

    private func split(_ text: String) -> (String, String) {
        guard let r = text.range(of: #"(?<=[.!?])\s+"#, options: .regularExpression) else { return (text, "") }
        return (String(text[..<r.lowerBound]), String(text[r.upperBound...]))
    }
}

// MARK: - 💸 Receipt (money / vote / record — from filings, always sourced)

struct ReceiptPage: View {
    let fact: Fact
    let candidate: Candidate
    @Environment(\.openURL) private var openURL
    @State private var slam = false

    private var kind: (label: String, emoji: String, color: Color) {
        switch fact.category {
        case "money": ("Follow the money", "💸", Theme.lime)
        case "vote": ("On the record", "🗳️", Theme.pink)
        case "endorsement": ("Backed by", "🤝", Theme.orange)
        case "identity": ("Who", "🪪", Theme.violet)
        default: ("Receipts", "🧾", Theme.cyan)
        }
    }

    private var isTable: Bool { fact.text.contains("\n") }
    private var lines: [String] { fact.text.components(separatedBy: "\n") }

    // pull $ figures and % out of the text so the numbers can be HUGE.
    // For a table (multi-line), only the headline row's numbers — the rest stay in their rows.
    private var numbers: [String] {
        let scan = isTable ? (lines.dropFirst().first ?? "") : fact.text
        let re = try! NSRegularExpression(pattern: #"\$[\d,.]+[MK]?|\d+(?:\.\d+)?%"#)
        let ns = scan as NSString
        return re.matches(in: scan, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // chaos layer: the numbers, enormous and faint, scattered behind
                ForEach(Array(numbers.prefix(4).enumerated()), id: \.offset) { i, n in
                    Text(n)
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundStyle(kind.color.opacity(0.14))
                        .rotationEffect(.degrees([-14, 9, -6, 17][i % 4]))
                        .offset(x: [-70, 90, -30, 60][i % 4] * (slam ? 1 : 1.6),
                                y: [-geo.size.height * 0.32, -geo.size.height * 0.12, geo.size.height * 0.25, geo.size.height * 0.36][i % 4])
                        .blur(radius: slam ? 0 : 12)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Spacer()
                    HStack(spacing: 8) {
                        Text(kind.emoji).font(.system(size: 30))
                        Sticker(kind.label, color: kind.color)
                            .rotationEffect(.degrees(slam ? -3 : 25))
                            .scaleEffect(slam ? 1 : 2.2)
                    }

                    // the receipt itself: paper, ink — the serious thing inside the party
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(numbers.prefix(isTable ? 1 : 3).enumerated()), id: \.offset) { _, n in
                            Text(n)
                                .font(.system(size: 40, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.ink)
                                .shadow(color: kind.color, radius: 0, x: 3, y: 3)
                        }
                        if isTable {
                            Text(lines[0])
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.ink.opacity(0.6))
                            ForEach(Array(lines.dropFirst().enumerated()), id: \.offset) { i, row in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(i == 0 ? "▶" : "·")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(i == 0 ? kind.color : Theme.ink.opacity(0.4))
                                        .frame(width: 12)
                                    Text(row)
                                        .font(.system(size: i == 0 ? 18 : 15, weight: i == 0 ? .black : .semibold, design: .rounded))
                                        .foregroundStyle(Theme.ink.opacity(i == 0 ? 1 : 0.75))
                                }
                            }
                        } else {
                            Text(fact.text)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Rectangle().fill(Theme.ink.opacity(0.15)).frame(height: 1).padding(.vertical, 4)
                        Button {
                            Haptic.tap()
                            openURL(fact.url)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("SOURCE: \(fact.source.uppercased())")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.ink)
                        }
                        .buttonStyle(SquishButton())
                    }
                    .padding(20)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .top) {
                        // torn-receipt edge
                        HStack(spacing: 0) {
                            ForEach(0..<22, id: \.self) { _ in
                                Triangle().fill(Theme.paper).frame(width: 16, height: 8)
                            }
                        }
                        .offset(y: -8)
                    }
                    .rotationEffect(.degrees(slam ? -1.5 : 6))
                    .scaleEffect(slam ? 1 : 0.7)
                    .shadow(color: kind.color.opacity(0.7), radius: slam ? 36 : 0, y: 12)
                    .opacity(slam ? 1 : 0)
                    Spacer()
                }
                .padding(22)
            }
        }
        .onAppear { withAnimation(.bouncy(duration: 0.55, extraBounce: 0.25)) { slam = true } }
        .onDisappear { slam = false }
    }
}

// MARK: - ⚔️ Pair — a vote and the money, side by side. The user draws the line.

struct PairPage: View {
    let fact: Fact
    let candidate: Candidate
    @Environment(\.openURL) private var openURL
    @State private var split = false

    private var halves: (vote: String, money: String) {
        let parts = fact.text.components(separatedBy: " ⟷ ")
        return (parts.first ?? fact.text, parts.count > 1 ? parts[1] : "")
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // top: the vote
                VStack(alignment: .leading, spacing: 10) {
                    Sticker("🗳️ The vote", color: Theme.pink).rotationEffect(.degrees(-3))
                    Spacer(minLength: 0)
                    Text(halves.vote)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.pink.opacity(0.6), radius: 20)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: geo.size.height * 0.46)
                .background(Theme.pink.opacity(0.18))
                .offset(x: split ? 0 : -geo.size.width)

                // the seam
                HStack {
                    Rectangle().fill(.white.opacity(0.35)).frame(height: 2)
                    Text("⟷")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(split ? 0 : 540))
                    Rectangle().fill(.white.opacity(0.35)).frame(height: 2)
                }
                .padding(.horizontal, 22)
                .frame(height: geo.size.height * 0.08)

                // bottom: the money, on paper
                VStack(alignment: .leading, spacing: 10) {
                    Sticker("💸 The money", color: Theme.lime).rotationEffect(.degrees(2))
                    Spacer(minLength: 0)
                    Text(halves.money)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    Button {
                        Haptic.tap()
                        openURL(fact.url)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("SOURCE: \(fact.source.uppercased())")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(SquishButton())
                    Text("Two facts, side by side. No causal claim — you draw the line.")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: geo.size.height * 0.46)
                .background(Theme.paper)
                .offset(x: split ? 0 : geo.size.width)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 14)
            .padding(.vertical, 60)
            .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        }
        .onAppear { withAnimation(.bouncy(duration: 0.7)) { split = true } }
        .onDisappear { split = false }
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.closeSubpath()
        return p
    }
}

// MARK: - One post, full screen

struct PostPage: View {
    let post: Post
    let color: Color
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // We never embed their media — only their words. A giant ghost quote mark fills the stage.
                Text("“")
                    .font(.system(size: 320, weight: .black, design: .serif))
                    .foregroundStyle(color.opacity(0.18))
                    .offset(x: -geo.size.width * 0.28, y: -geo.size.height * 0.30)

                VStack(alignment: .leading, spacing: 14) {
                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        Sticker(post.isOfficial ? "Official office" : "Personal", color: post.isOfficial ? Theme.cyan : Theme.pink)
                        Sticker(post.platformLabel, color: .white.opacity(0.9))
                        Spacer()
                        if let d = post.date {
                            Text(d, format: .dateTime.month(.abbreviated).day().year())
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    Text(displayText)
                        .font(.system(size: bigSize, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                        .lineLimit(10)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if post.image != nil || post.video != nil {
                        let n = post.media.filter { $0.type == "image" }.count
                        Button { openURL(post.url) } label: {
                            HStack(spacing: 8) {
                                Text(post.video != nil ? "🎬" : "📷")
                                Text(post.video != nil ? "has a video" : n == 1 ? "has a photo" : "has \(n) photos")
                                Text("· view on \(post.platformLabel)")
                                    .foregroundStyle(color)
                            }
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(SquishButton())
                    }

                    if let q = post.quoted {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("@\(q.handle)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(color)
                            Text(q.text)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(4)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.2), lineWidth: 1))
                    }

                    if let l = post.link, let title = l.title {
                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .font(.system(size: 13, weight: .black))
                            Text(title)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .lineLimit(2)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.2), lineWidth: 1))
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 14) {
                        Metric("heart.fill", post.metrics.likes)
                        Metric("arrow.2.squarepath", post.metrics.reposts)
                        Metric("bubble.left.fill", post.metrics.replies)
                        Spacer()
                        Button {
                            Haptic.tap()
                            openURL(post.url)
                        } label: {
                            HStack(spacing: 6) {
                                Text("@\(post.account.handle.replacingOccurrences(of: ".bsky.social", with: ""))")
                                    .lineLimit(1)
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.bg)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(color, in: Capsule())
                            .shadow(color: color.opacity(0.7), radius: 12, y: 4)
                        }
                        .buttonStyle(SquishButton())
                    }
                }
                .padding(20)
            }
        }
    }

    // Display only — the stored text is verbatim. When the post has a link card, the bare
    // URL in the body is redundant noise, so it's hidden on screen.
    private var displayText: String {
        guard post.link != nil else { return post.text }
        let stripped = post.text.replacingOccurrences(
            of: #"\s*(?:https?://|www\.)\S+(?:\.\.\.|…)?\s*$"#, with: "", options: .regularExpression)
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bigSize: CGFloat {
        switch displayText.count {
        case ..<60: 44
        case ..<140: 34
        case ..<220: 28
        default: 24
        }
    }

}

struct Shimmer: View {
    let color: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            LinearGradient(colors: [Theme.card, color.opacity(0.35), Theme.card],
                           startPoint: UnitPoint(x: (t * 0.6).truncatingRemainder(dividingBy: 2) - 1, y: 0),
                           endPoint: UnitPoint(x: (t * 0.6).truncatingRemainder(dividingBy: 2), y: 1))
        }
    }
}

struct Metric: View {
    let icon: String, n: Int
    init(_ icon: String, _ n: Int) { self.icon = icon; self.n = n }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .black))
            Text("\(n)").font(.system(size: 13, weight: .black, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}
