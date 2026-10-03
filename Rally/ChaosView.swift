import SwiftUI
import WebKit

// 🎲 CHAOS MODE — a random real clip. Shake (iOS) or tap for another.
struct ChaosView: View {
    let candidate: Candidate
    let clips: [Clip]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var clip: Clip?
    @State private var spin = 0.0
    private var color: Color { Theme.party(candidate.party) }

    var body: some View {
        ZStack {
            LavaLamp(seed: 42 + spin / 360)
                .ignoresSafeArea()

            VStack(spacing: 18) {
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
                    Sticker("🎲 Chaos mode", color: Theme.lime)
                        .rotationEffect(.degrees(-3))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if let clip {
                    VStack(alignment: .leading, spacing: 12) {
                        YouTubeEmbed(url: clip.embedUrl)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.25), lineWidth: 1))
                            .shadow(color: color.opacity(0.5), radius: 30, y: 10)
                            .id(clip.id)

                        Text(clip.title)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)

                        HStack(spacing: 8) {
                            Sticker(clip.channel, color: .white.opacity(0.9))
                            if let d = clip.publishedAt { Sticker(d, color: Theme.dim) }
                            if !clip.durationLabel.isEmpty { Sticker(clip.durationLabel, color: Theme.dim) }
                            Spacer()
                            Button { openURL(clip.url) } label: {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .black))
                                    .frame(width: 32, height: 32)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("100% real footage · verified by a human · tap ↗ for the source")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                    }
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity),
                                            removal: .opacity))
                } else {
                    EmptyStage(text: "No verified clips for \(candidate.name) yet.", color: color)
                }

                Spacer()

                Button {
                    roll()
                } label: {
                    HStack(spacing: 12) {
                        Text("🎲")
                            .font(.system(size: 30))
                            .rotationEffect(.degrees(spin))
                        Text(clips.count > 1 ? "ANOTHER ONE" : "REPLAY")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Theme.lime, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: Theme.lime.opacity(0.7), radius: 24, y: 8)
                }
                .buttonStyle(SquishButton())
                .disabled(clips.isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                #if os(iOS)
                Text("or shake your phone 📳")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                    .padding(.bottom, 16)
                #endif
            }
        }
        .background(Theme.bg)
        .onAppear { if clip == nil { roll(animated: false) } }
        .onShake { roll() }
    }

    private func roll(animated: Bool = true) {
        guard !clips.isEmpty else { return }
        Haptic.tap()
        let next = clips.count > 1 ? clips.filter { $0.id != clip?.id }.randomElement() : clips.first
        withAnimation(animated ? .bouncy(duration: 0.6) : nil) {
            spin += 360
            clip = next
        }
    }
}

// MARK: - YouTube embed (official player, per YouTube ToS)

#if os(iOS)
struct YouTubeEmbed: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.isOpaque = false; v.backgroundColor = .clear; v.scrollView.isScrollEnabled = false
        return v
    }
    func updateUIView(_ v: WKWebView, context: Context) { v.load(URLRequest(url: url)) }
}
#else
struct YouTubeEmbed: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView { WKWebView() }
    func updateNSView(_ v: WKWebView, context: Context) { v.load(URLRequest(url: url)) }
}
#endif

// MARK: - Shake

#if os(iOS)
extension UIDevice { static let shaken = Notification.Name("rally.shake") }
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { NotificationCenter.default.post(name: UIDevice.shaken, object: nil) }
        super.motionEnded(motion, with: event)
    }
}
extension View {
    func onShake(_ action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIDevice.shaken)) { _ in action() }
    }
}
#else
extension View {
    func onShake(_ action: @escaping () -> Void) -> some View { self }
}
#endif
