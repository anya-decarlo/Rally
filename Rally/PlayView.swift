import SwiftUI

// The arcade. Everything fun lives here — faceoffs, booth, chaos, and every
// game we invent next. Not tied to any one candidate.
struct PlayView: View {
    @Environment(FashionStore.self) private var fashion
    @Environment(ExtrasStore.self) private var extras
    @State private var openFaceoff: Faceoff?
    @State private var boothCandidate: Candidate?
    @State private var chaosCandidate: Candidate?
    @State private var boothPicker = false

    private var boothPlayers: [Candidate] {
        Ballot.allCandidates.filter { extras.portrait(for: $0) != nil }
    }
    private var chaosPlayers: [Candidate] {
        Ballot.allCandidates.filter { !extras.clips(for: $0).isEmpty }
    }

    var body: some View {
        ZStack {
            LavaLamp(seed: 7)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    Text("PLAY")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .white, Theme.pink],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: Theme.pink.opacity(0.9), radius: 0, x: 3, y: 3)
                        .shadow(color: Theme.pink.opacity(0.5), radius: 30)
                        .padding(.top, 8)

                    if !fashion.faceoffs.isEmpty {
                        section("FACEOFFS") {
                            ForEach(fashion.faceoffs) { f in
                                FaceoffTile(faceoff: f) { openFaceoff = f }
                            }
                            if !fashion.votes.isEmpty {
                                Button {
                                    Haptic.tick()
                                    fashion.resetVotes()
                                } label: {
                                    Text("↺ reset my votes (demo)")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(Theme.dim)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !boothPlayers.isEmpty {
                        section("STICKER BOOTH") {
                            ArcadeTile(emoji: "🌸", title: "BOOTH", sub: "pick a face", color: Theme.pink) {
                                withAnimation(.bouncy(duration: 0.4)) { boothPicker.toggle() }
                            }
                            if boothPicker {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(boothPlayers) { c in
                                            Button {
                                                Haptic.tap()
                                                boothCandidate = c
                                            } label: {
                                                Text(c.name)
                                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                                    .foregroundStyle(Theme.bg)
                                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                                    .background(Theme.pink, in: Capsule())
                                                    .shadow(color: Theme.pink.opacity(0.6), radius: 10)
                                            }
                                            .buttonStyle(SquishButton())
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }

                    if !chaosPlayers.isEmpty {
                        section("CHAOS") {
                            ForEach(chaosPlayers) { c in
                                ArcadeTile(emoji: "🎲", title: "CHAOS", sub: c.name, color: Theme.lime) {
                                    chaosCandidate = c
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg)
        .fullScreenCoverCompat(item: $openFaceoff) { f in
            ZStack(alignment: .topTrailing) {
                FaceoffPage(faceoff: f)
                Button {
                    Haptic.tick()
                    openFaceoff = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 60)
                .padding(.trailing, 16)
            }
            .background(Theme.bg)
        }
        .fullScreenCoverCompat(item: $boothCandidate) { c in
            if let p = extras.portrait(for: c) {
                BoothView(candidate: c, portrait: p) { boothCandidate = nil }
            }
        }
        .fullScreenCoverCompat(item: $chaosCandidate) { c in
            ChaosView(candidate: c, clips: extras.clips(for: c))
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(Theme.dim)
            content()
        }
    }
}

// A faceoff as a lobby tile — both looks peeking, live countdown.
struct FaceoffTile: View {
    let faceoff: Faceoff
    let onTap: () -> Void
    @Environment(FashionStore.self) private var fashion

    var body: some View {
        Button {
            Haptic.tap()
            onTap()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(faceoff.looks(in: fashion).prefix(2)) { look in
                        LookImage(look: look)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipped()
                    }
                }
                HStack {
                    Text(faceoff.title.uppercased())
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    if faceoff.isOpen {
                        Text(faceoff.closesAt, style: .timer)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.yellow)
                        Text("LEFT")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.yellow.opacity(0.7))
                    } else {
                        Text("CLOSED")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(LinearGradient(colors: [.white.opacity(0.8), Theme.pink.opacity(0.5), .white.opacity(0.1)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Theme.pink.opacity(0.4), radius: 16, y: 6)
        }
        .buttonStyle(SquishButton())
    }
}

struct ArcadeTile: View {
    let emoji: String, title: String, sub: String, color: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 54, height: 54)
                    .background(color.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.6), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(sub)
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(LinearGradient(colors: [.white.opacity(0.7), color.opacity(0.4), .white.opacity(0.1)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(SquishButton())
    }
}
