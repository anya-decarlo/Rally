import SwiftUI

// A feed item is a post, or — every few swipes — a fun fact.
enum FeedItem: Identifiable {
    case post(Post), fact(Fact)
    var id: String {
        switch self { case .post(let p): p.id; case .fact(let f): "fact:" + f.id }
    }

    static let factEvery = 3   // a fun fact after every N posts

    static func interleave(posts: [Post], facts: [Fact], every n: Int = factEvery) -> [FeedItem] {
        var out: [FeedItem] = [], f = facts.shuffled().makeIterator()
        for (i, p) in posts.enumerated() {
            out.append(.post(p))
            if (i + 1) % n == 0, let fact = f.next() { out.append(.fact(fact)) }
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
                                case .fact(let fact): FactPage(fact: fact, candidate: candidate)
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

                    Text(post.text)
                        .font(.system(size: bigSize, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                        .lineLimit(12)
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

    private var bigSize: CGFloat {
        switch post.text.count {
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
