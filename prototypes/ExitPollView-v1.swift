import SwiftUI
import AVKit

// 🗳️ EXIT POLL — a fake agree/disagree poll that secretly sorts you onto a
// side. You get the other guy. The timer starts the instant the clip pops and
// stops the instant you bail. Clips are bundled mp4s in data/clips/.
struct ExitPollView: View {
    @Environment(\.dismiss) private var dismiss

    enum Side {
        case ukraine, russia
        var label: String { self == .ukraine ? "UKRAINE" : "RUSSIA" }
        var opponent: Leader { self == .ukraine ? .putin : .zelensky }
        var other: Side { self == .ukraine ? .russia : .ukraine }
    }

    struct Question {
        let text: String
        let agreeSide: Side // what agreeing secretly implies
    }

    static let questions: [Question] = [
        .init(text: "Comedians have no business running a country.", agreeSide: .russia),
        .init(text: "The strongest leader is the one who never gives power back.", agreeSide: .russia),
        .init(text: "Nobody should hold power for more than a decade.", agreeSide: .ukraine),
        .init(text: "Borders are just suggestions if you're strong enough.", agreeSide: .russia),
        .init(text: "You can't negotiate with a tank parked on your lawn.", agreeSide: .ukraine),
        .init(text: "Every nation gets the leader it tolerates.", agreeSide: .russia),
    ]

    enum Leader {
        case putin, zelensky
        var name: String { self == .putin ? "PUTIN" : "ZELENSKY" }
        var face: String { self == .putin ? "🐻" : "🎤" }
        var color: Color { self == .putin ? Theme.orange : Theme.cyan }
        var clip: String { self == .putin ? "putin" : "zelensky" }
    }

    enum Phase { case pick, watch, result }

    @State private var phase: Phase = .pick
    @State private var question = ExitPollView.questions.randomElement()!
    @State private var agreed = false
    @State private var side: Side?
    @State private var start = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var best: TimeInterval = UserDefaults.standard.double(forKey: "rally.exitpoll.best")
    @State private var newBest = false

    private var leader: Leader? { side?.opponent }

    var body: some View {
        ZStack {
            LavaLamp(seed: side == .russia ? 13 : 3)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    if phase != .watch {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .black))
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Sticker("🎙️ on the record", color: Theme.paper)
                        .rotationEffect(.degrees(-3))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                switch phase {
                case .pick: pickScreen
                case .watch: watchScreen
                case .result: resultScreen
                }
            }
        }
        .background(Theme.bg)
    }

    // MARK: - The "poll" — reads like a press pool question, lands like a trap

    private var pickScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("FOR THE\nRECORD.")
                .font(.system(size: 44, weight: .black, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("A member of the press pool will now read a statement. Please respond honestly.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 12) {
                Text("Q — DO YOU AGREE OR DISAGREE:")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.dim)
                Text("“\(question.text)”")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.edge, lineWidth: 1))

            Spacer()
            answerButton(agree: true)
            answerButton(agree: false)
            Text("your response is on the record.")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func answerButton(agree: Bool) -> some View {
        Button {
            Haptic.tap()
            agreed = agree
            side = agree ? question.agreeSide : question.agreeSide.other
            start = Date()
            withAnimation(.bouncy(duration: 0.5)) { phase = .watch }
        } label: {
            Text(agree ? "AGREE" : "DISAGREE")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .tracking(3)
                .foregroundStyle(agree ? Theme.ink : Theme.paper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(agree ? Theme.paper : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.paper.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - The popup clip + live stopwatch

    private var watchScreen: some View {
        VStack(spacing: 20) {
            TimelineView(.periodic(from: start, by: 1.0 / 30.0)) { tl in
                Text(String(format: "%.2f", tl.date.timeIntervalSince(start)))
                    .font(.system(size: 64, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.yellow)
                    .shadow(color: Theme.yellow.opacity(0.7), radius: 18)
                    .monospacedDigit()
            }
            Text("TIME ON THE OTHER SIDE")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Theme.dim)

            if let leader {
                VStack(spacing: 14) {
                    clipStage(leader)
                    HStack(spacing: 8) {
                        Sticker("you picked \(side?.label ?? "")", color: .white.opacity(0.9))
                        Sticker("starring: \(leader.name)", color: leader.color)
                    }
                }
                .padding(.horizontal, 16)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            Spacer()

            Button {
                bail()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .black))
                    Text("GET ME OUT")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Theme.pink, in: RoundedRectangle(cornerRadius: 28))
                .shadow(color: Theme.pink.opacity(0.7), radius: 24, y: 8)
            }
            .buttonStyle(SquishButton())
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private func clipStage(_ leader: Leader) -> some View {
        ZStack(alignment: .topLeading) {
            if Bundle.main.url(forResource: leader.clip, withExtension: "mp4") != nil {
                BundledClipView(resource: leader.clip)
            } else {
                clipPlaceholder(leader)
            }
            liveBadge.padding(12)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(leader.color.opacity(0.6), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: leader.color.opacity(0.5), radius: 30, y: 10)
    }

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(.red).frame(width: 8, height: 8)
            Text("LIVE-ish")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.black.opacity(0.55), in: Capsule())
    }

    private func clipPlaceholder(_ leader: Leader) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.card)
            VStack(spacing: 10) {
                Text(leader.face)
                    .font(.system(size: 72))
                Text(leader.name)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("📼 clip drops in later — the timer doesn't wait")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
        }
    }

    // MARK: - Result

    private var resultScreen: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(String(format: "%.2fs", elapsed))
                .font(.system(size: 72, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.yellow)
                .shadow(color: Theme.yellow.opacity(0.7), radius: 24)
                .monospacedDigit()
            if newBest {
                Sticker("★ new personal best", color: Theme.lime)
                    .rotationEffect(.degrees(-2))
            } else if best > 0 {
                Text(String(format: "personal best %.2fs", best))
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
            Text(verdict)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if let leader {
                Text("\(agreed ? "agreed" : "disagreed") · fled \(leader.name.lowercased())")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
            Spacer()
            Button {
                Haptic.tap()
                question = Self.questions.filter { $0.text != question.text }.randomElement() ?? question
                phase = .pick
                newBest = false
            } label: {
                Text("RUN IT BACK")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Theme.lime, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: Theme.lime.opacity(0.7), radius: 24, y: 8)
            }
            .buttonStyle(SquishButton())
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private var verdict: String {
        switch elapsed {
        case ..<0.5: return "Pure reflex. Didn't even see the face."
        case ..<1.5: return "No hesitation. Zero curiosity."
        case ..<4: return "Gave it a second. One second."
        case ..<10: return "Actually listened a little. Suspiciously open-minded."
        default: return "Watched the whole thing. Both sides are confused."
        }
    }

    private func bail() {
        Haptic.tick()
        elapsed = Date().timeIntervalSince(start)
        if elapsed < best || best == 0 {
            best = elapsed
            newBest = true
            UserDefaults.standard.set(elapsed, forKey: "rally.exitpoll.best")
        }
        withAnimation(.bouncy(duration: 0.4)) { phase = .result }
    }
}

// MARK: - Bundled clip player (mp4s in data/clips/, loops with sound, no controls)

struct BundledClipView: View {
    let resource: String
    @State private var player = AVQueuePlayer()
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ClipPlayerLayer(player: player)
            .onAppear {
                guard looper == nil,
                      let url = Bundle.main.url(forResource: resource, withExtension: "mp4") else { return }
                looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                player.play()
            }
            .onDisappear { player.pause() }
    }
}

#if os(iOS)
struct ClipPlayerLayer: UIViewControllerRepresentable {
    let player: AVQueuePlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspectFill
        return vc
    }
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}
#else
struct ClipPlayerLayer: NSViewRepresentable {
    let player: AVQueuePlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .none
        v.videoGravity = .resizeAspectFill
        return v
    }
    func updateNSView(_ v: AVPlayerView, context: Context) {}
}
#endif

#Preview {
    ExitPollView()
}
