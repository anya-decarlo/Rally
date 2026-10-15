import SwiftUI

// WHO WORE IT BEST — tap a side to vote. One vote per device, polls close for real.
struct FaceoffPage: View {
    let faceoff: Faceoff
    @Environment(FashionStore.self) private var fashion
    @State private var voted = false

    private var looks: [Look] { faceoff.looks(in: fashion) }
    private var pick: String? { fashion.pick(in: faceoff) }
    private var tally: Backend.FaceoffResults? { fashion.results[faceoff.id] }
    private var showResults: Bool { pick != nil || !faceoff.isOpen }

    private func pct(for look: Look) -> Int? {
        guard showResults, let t = tally, t.total > 0 else { return nil }
        return Int((Double(t.votes[look.id] ?? 0) / Double(t.total) * 100).rounded())
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(looks.prefix(2).enumerated()), id: \.element.id) { _, look in
                    LookHalf(look: look,
                             picked: pick == look.id,
                             dimmed: pick != nil && pick != look.id,
                             pct: pct(for: look)) {
                        guard faceoff.isOpen, pick == nil else { return }
                        Haptic.tap()
                        withAnimation(.bouncy(duration: 0.4)) { voted = true }
                        fashion.vote(faceoff, for: look)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .overlay {
                Text("VS")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 52, height: 52)
                    .background(Theme.yellow, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: Theme.yellow, radius: 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 14)
            .padding(.top, 120)
            .padding(.bottom, 24)
            .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        }
        .overlay(alignment: .top) {
            HStack(spacing: 8) {
                Sticker(faceoff.title, color: Theme.pink)
                    .rotationEffect(.degrees(-3))
                if faceoff.isOpen {
                    HStack(spacing: 6) {
                        Text("⏱")
                        Text(faceoff.closesAt, style: .timer)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 8))
                    .rotationEffect(.degrees(2))
                } else {
                    Sticker("POLLS CLOSED", color: Theme.dim)
                        .rotationEffect(.degrees(2))
                }
            }
            .padding(.top, 66)
        }
        .onAppear {
            if showResults { Task { await fashion.refreshResults(faceoff) } }
        }
    }

}

private struct LookHalf: View {
    let look: Look
    let picked: Bool
    let dimmed: Bool
    var pct: Int? = nil
    let onVote: () -> Void

    var body: some View {
        Button(action: onVote) {
            ZStack(alignment: .bottomLeading) {
                LookImage(look: look)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(dimmed ? Color.black.opacity(0.55) : .clear)

                VStack(alignment: .leading, spacing: 4) {
                    if let pct {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(pct)%")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.7), radius: 6, y: 2)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.25))
                                    Capsule().fill(picked ? Theme.lime : .white.opacity(0.8))
                                        .frame(width: g.size.width * CGFloat(pct) / 100)
                                }
                            }
                            .frame(height: 6)
                        }
                        .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
                    }
                    if picked {
                        Text("YOUR PICK 👑")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.bg)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.lime, in: RoundedRectangle(cornerRadius: 7))
                            .rotationEffect(.degrees(-3))
                    }
                    Text(look.person)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 4, y: 1)
                    if let event = look.event {
                        Text(event + (look.source.map { " · \($0)" } ?? ""))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(picked ? 1.02 : 1)
    }
}

struct LookImage: View {
    let look: Look

    var body: some View {
        if let url = look.imageURL, let data = try? Data(contentsOf: url) {
            #if os(iOS)
            if let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            }
            #else
            if let img = NSImage(data: data) {
                Image(nsImage: img).resizable().scaledToFill()
            }
            #endif
        } else {
            Theme.card
        }
    }
}
