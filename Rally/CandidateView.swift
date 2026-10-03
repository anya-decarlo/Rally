import SwiftUI

// Shows exactly what we know. Nothing else pretends to be here.
struct CandidateView: View {
    let candidate: Candidate
    @Environment(PostStore.self) private var store
    @Environment(ExtrasStore.self) private var extras
    @State private var showFeed = false
    @State private var showChaos = false
    @State private var showBooth = false
    private var color: Color { Theme.party(candidate.party) }
    private var posts: [Post] { store.posts(for: candidate) }

    var body: some View {
        ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                Text(initials)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 76, height: 76)
                    .background(color, in: RoundedRectangle(cornerRadius: 24))
                    .rotationEffect(.degrees(-6))
                    .shadow(color: color.opacity(0.6), radius: 16, y: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(candidate.name)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        Sticker(candidate.party.label, color: color)
                        if candidate.incumbent { Sticker("Incumbent 👑", color: Theme.yellow) }
                        if candidate.writeIn { Sticker("Write-in ✍️", color: Theme.dim) }
                    }
                }
            }

            if !posts.isEmpty {
                Button {
                    Haptic.tap()
                    showFeed = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Theme.bg)
                            .frame(width: 54, height: 54)
                            .background(color, in: RoundedRectangle(cornerRadius: 18))
                            .shadow(color: color, radius: 14)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("THE FEED")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(posts.count) posts · in their own words")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundStyle(color)
                        }
                        Spacer()
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(LinearGradient(colors: [.white.opacity(0.8), color.opacity(0.4), .white.opacity(0.1)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    )
                    .shadow(color: color.opacity(0.35), radius: 20, y: 8)
                }
                .buttonStyle(SquishButton())
                .floating(phase: 2)
            }

            // PLAY — clearly separate from the receipts. Real footage, real portrait, just fun.
            let clips = extras.clips(for: candidate)
            let portrait = extras.portrait(for: candidate)
            if !clips.isEmpty || portrait != nil {
                HStack(spacing: 10) {
                    if !clips.isEmpty {
                        PlayTile(emoji: "🎲", title: "CHAOS", sub: "\(clips.count) real clip\(clips.count == 1 ? "" : "s")", color: Theme.lime) {
                            showChaos = true
                        }
                    }
                    if portrait != nil {
                        PlayTile(emoji: "🌸", title: "BOOTH", sub: "sticker playground", color: Theme.pink) {
                            showBooth = true
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RECEIPTS")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(color)
                Text("No filings or clips loaded yet.\nWhen they're here, every number links to its source.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.dim)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bg.opacity(0.5), in: RoundedRectangle(cornerRadius: 22))

        }
        .padding(24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.card)
        .fullScreenCoverCompat(isPresented: $showFeed) {
            FeedView(candidate: candidate, posts: posts, facts: extras.facts(for: candidate))
        }
        .fullScreenCoverCompat(isPresented: $showChaos) {
            ChaosView(candidate: candidate, clips: extras.clips(for: candidate))
        }
        .fullScreenCoverCompat(isPresented: $showBooth) {
            if let p = extras.portrait(for: candidate) { BoothView(candidate: candidate, portrait: p) }
        }
    }

    private var initials: String {
        candidate.name.split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
    }
}

struct PlayTile: View {
    let emoji: String, title: String, sub: String, color: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(emoji).font(.system(size: 34))
                Spacer(minLength: 4)
                Text(title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(sub)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(LinearGradient(colors: [.white.opacity(0.8), color.opacity(0.5), .white.opacity(0.1)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.4), radius: 16, y: 6)
        }
        .buttonStyle(SquishButton())
    }
}

extension View {
    @ViewBuilder
    func fullScreenCoverCompat<C: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> C) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented) { content().frame(minWidth: 480, minHeight: 820) }
        #endif
    }
}
