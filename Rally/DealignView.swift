import SwiftUI

// 🚩 DEALIGN — an interactive civics intervention. Every tap collectivizes
// something slightly bigger until you're fully de-aligned from democratic-
// republic values. There is exactly one outcome.
struct DealignView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var score = 0.0
    @State private var taps = 0
    @State private var feed: [String] = []

    private var done: Bool { score >= 100 }

    private static let loot: [(until: Double, items: [String])] = [
        (25, ["your roommate's leftovers", "the office stapler", "a parking spot", "your oat milk", "the neighbor's wifi password"]),
        (50, ["the break room", "your landlord's second unit", "the group chat", "a brunch reservation", "the company espresso machine"]),
        (75, ["the delivery vans", "the factory floor", "the water supply", "the regional grid", "the farmers' market"]),
        (95, ["the means of production", "the ports", "the railways", "the banks", "the almond farms"]),
        (.infinity, ["the economy", "congress", "the federal reserve", "the republic itself"]),
    ]

    private var rank: String {
        switch score {
        case ..<20: "free-market individualist"
        case ..<40: "union-curious"
        case ..<60: "co-op member"
        case ..<80: "seizing the means"
        case ..<100: "almost comrade"
        default: "democratic socialist"
        }
    }

    var body: some View {
        ZStack {
            LavaLamp(seed: 9, speed: 0.4)
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
                    Sticker("🚩 dealign", color: Theme.orange)
                        .rotationEffect(.degrees(-3))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if done { doneScreen } else { playScreen }
            }
        }
        .background(Theme.bg)
    }

    // MARK: - The intervention

    private var playScreen: some View {
        VStack(spacing: 22) {
            Spacer()

            Text("CIVIC REALIGNMENT\nIN PROGRESS")
                .font(.system(size: 30, weight: .black, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(String(format: "%.0f%%", score))
                .font(.system(size: 72, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.orange)
                .monospacedDigit()
            Text("SOCIALIZED")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Theme.dim)

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.edge)
                    Capsule().fill(Theme.orange)
                        .frame(width: g.size.width * score / 100)
                }
            }
            .frame(height: 10)
            .padding(.horizontal, 32)
            .animation(.bouncy(duration: 0.4), value: score)

            Text("current status: \(rank)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.orange)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(feed, id: \.self) { item in
                    Text("✓ collectivized \(item)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(height: 96, alignment: .top)

            Spacer()

            Button { collectivize() } label: {
                Text("COLLECTIVIZE")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Theme.orange, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: Theme.orange.opacity(0.7), radius: 24, y: 8)
            }
            .buttonStyle(SquishButton())
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Certified outcome

    private var doneScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("DE-ALIGNMENT\nCOMPLETE")
                .font(.system(size: 44, weight: .black, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text("CERTIFIED DESIGNATION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.dim)
                Text("You are now a democratic socialist.")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().overlay(Theme.edge)
                HStack {
                    Text("\(taps) assets collectivized")
                    Spacer()
                    Text("appeals: 0")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.edge, lineWidth: 1))

            Text("This designation is permanent and cannot be appealed. You have been fully de-aligned from democratic-republic values.")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Haptic.tap()
                score = 0; taps = 0; feed = []
            } label: {
                Text("REALIGN ANOTHER CITIZEN")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .tracking(3)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    private func collectivize() {
        Haptic.tap()
        taps += 1
        withAnimation {
            score = min(100, score + Double.random(in: 2...6))
            let pool = Self.loot.first { score <= $0.until }!.items
            feed.insert(pool.randomElement()!, at: 0)
            if feed.count > 4 { feed.removeLast() }
        }
    }
}

#Preview {
    DealignView()
}
