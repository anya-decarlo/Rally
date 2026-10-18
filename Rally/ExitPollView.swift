import SwiftUI
import AVKit

// 🗳️ EXIT POLL — a fake agree/disagree poll that secretly sorts you onto a
// side. You get the other guy, full screen, no warning. The hidden timer stops
// when the clip ends or you find the little ✕. Clips are bundled mp4s in
// data/clips/.
struct ExitPollView: View {
    @Environment(\.dismiss) private var dismiss

    enum Leader {
        case putin, zelensky, netanyahu, abbas
        var name: String {
            switch self {
            case .putin: "PUTIN"
            case .zelensky: "ZELENSKY"
            case .netanyahu: "NETANYAHU"
            case .abbas: "ABBAS"
            }
        }
        var face: String {
            switch self {
            case .putin: "🐻"
            case .zelensky: "🎤"
            case .netanyahu: "🪖"
            case .abbas: "🕊️"
            }
        }
        var color: Color {
            switch self {
            case .putin: Theme.orange
            case .zelensky: Theme.cyan
            case .netanyahu: Theme.violet
            case .abbas: Theme.lime
            }
        }
        var clip: String {
            switch self {
            case .putin: "putin"
            case .zelensky: "zelensky"
            case .netanyahu: "netanyahu"
            case .abbas: "abbas"
            }
        }
    }

    // Each statement secretly leans one way. Whichever way you lean, you get the
    // OTHER guy's clip — agree or disagree, someone you're not expecting shows up.
    struct Question {
        let text: String
        let agreeClip: Leader
        let disagreeClip: Leader
    }

    static let questions: [Question] = [
        // ukraine / russia
        .init(text: "Comedians have no business running a country.", agreeClip: .zelensky, disagreeClip: .putin),
        .init(text: "The strongest leader is the one who never gives power back.", agreeClip: .zelensky, disagreeClip: .putin),
        .init(text: "Nobody should hold power for more than a decade.", agreeClip: .putin, disagreeClip: .zelensky),
        .init(text: "Borders are just suggestions if you're strong enough.", agreeClip: .zelensky, disagreeClip: .putin),
        .init(text: "You can't negotiate with a tank parked on your lawn.", agreeClip: .putin, disagreeClip: .zelensky),
        .init(text: "Every nation gets the leader it tolerates.", agreeClip: .zelensky, disagreeClip: .putin),
        // gaza / israel
        .init(text: "Security comes first. Everything else is a detail.", agreeClip: .abbas, disagreeClip: .netanyahu),
        .init(text: "You can't bomb your way to peace.", agreeClip: .netanyahu, disagreeClip: .abbas),
        .init(text: "Ceasefires only help the side that's losing.", agreeClip: .abbas, disagreeClip: .netanyahu),
        .init(text: "If a child's home is rubble, the strategy already failed.", agreeClip: .netanyahu, disagreeClip: .abbas),
        .init(text: "A nation under attack doesn't owe anyone restraint.", agreeClip: .abbas, disagreeClip: .netanyahu),
        .init(text: "Land taken by force is never really yours.", agreeClip: .netanyahu, disagreeClip: .abbas),
    ]

    enum Phase { case pick, watch, result }

    @State private var phase: Phase = .pick
    @State private var question = ExitPollView.questions.randomElement()!
    @State private var agreed = false
    @State private var leader: Leader?
    @State private var start = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var best: TimeInterval = UserDefaults.standard.double(forKey: "rally.exitpoll.best")
    @State private var newBest = false

    var body: some View {
        ZStack {
            if phase == .watch {
                watchLayer
                    .transition(.opacity)
            } else {
                LavaLamp(seed: Double(abs(question.text.hashValue) % 10))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .black))
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Sticker("🎙️ on the record", color: Theme.paper)
                            .rotationEffect(.degrees(-3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    switch phase {
                    case .pick: pickScreen
                    case .result: resultScreen
                    case .watch: EmptyView()
                    }
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
            leader = agree ? question.agreeClip : question.disagreeClip
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

    // MARK: - The ambush — the clip hijacks the whole screen. No exit button,
    // no stopwatch in sight. The clock only stops when the video ends or they
    // find the little ✕.

    private var watchLayer: some View {
        ZStack(alignment: .top) {
            if let leader {
                Group {
                    if Bundle.main.url(forResource: leader.clip, withExtension: "mp4") != nil {
                        BundledClipView(resource: leader.clip) { bail() }
                    } else {
                        clipPlaceholder(leader)
                    }
                }
                .background(Color.black)
                .ignoresSafeArea()
            }
            HStack {
                liveBadge
                Spacer()
                Button { bail() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
        }
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
                replay()
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
            Text("↑ swipe up for another question")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .padding(.bottom, 24)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { g in
                    if g.translation.height < 0 { replay() }
                }
        )
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

    private func replay() {
        Haptic.tap()
        question = Self.questions.filter { $0.text != question.text }.randomElement() ?? question
        withAnimation(.bouncy(duration: 0.4)) { phase = .pick }
        newBest = false
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

// MARK: - Bundled clip player (mp4s in data/clips/, plays once, no controls)

struct BundledClipView: View {
    let resource: String
    var onEnd: () -> Void = {}
    @State private var player = AVQueuePlayer()
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        ClipPlayerLayer(player: player)
            .onAppear {
                guard player.currentItem == nil,
                      let url = Bundle.main.url(forResource: resource, withExtension: "mp4") else { return }
                let item = AVPlayerItem(url: url)
                endObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
                ) { _ in onEnd() }
                player.replaceCurrentItem(with: item)
                player.play()
            }
            .onDisappear {
                player.pause()
                if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            }
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
