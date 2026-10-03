import SwiftUI

// The ballot as stories. Swipe sideways. Never scroll down.
struct StoriesView: View {
    let place: Place
    let onChangePlace: () -> Void
    private let contests: [Contest]
    @State private var current: String?
    @State private var selected: Candidate?

    init(place: Place, onChangePlace: @escaping () -> Void) {
        self.place = place
        self.onChangePlace = onChangePlace
        contests = Ballot.contests(for: place)
        _current = State(initialValue: contests.first?.id)
    }

    private var currentIndex: Int {
        contests.firstIndex { $0.id == current } ?? 0
    }
    private var currentGroup: ContestGroup { contests[currentIndex].group }

    var body: some View {
        ZStack {
            LavaLamp(seed: Double(currentIndex))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(count: contests.count, index: currentIndex, color: Theme.group(currentGroup))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                HStack(spacing: 8) {
                    Button {
                        Haptic.tick()
                        onChangePlace()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.circle.fill")
                            Text(place.id)
                        }
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)

                    ChapterBar(selected: currentGroup) { group in
                        Haptic.tick()
                        withAnimation(.snappy) {
                            current = contests.first { $0.group == group }?.id
                        }
                    }
                }
                .padding(.top, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(contests) { contest in
                            ContestPage(contest: contest) { selected = $0 }
                                .containerRelativeFrame(.horizontal)
                                .id(contest.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $current)
                .onChange(of: current) { Haptic.tick() }
            }
        }
        .background(Theme.bg)
        .sheet(item: $selected) { candidate in
            CandidateView(candidate: candidate)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.card)
                .presentationCornerRadius(32)
        }
    }
}

// MARK: - Stories progress

struct ProgressBar: View {
    let count: Int, index: Int, color: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? color : Color.white.opacity(0.18))
                    .frame(height: 3)
            }
        }
        .animation(.snappy, value: index)
    }
}

// MARK: - Chapter pills

struct ChapterBar: View {
    let selected: ContestGroup
    let onPick: (ContestGroup) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ContestGroup.allCases, id: \.self) { g in
                    let on = g == selected
                    Button { onPick(g) } label: {
                        Text(g.rawValue.uppercased())
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(1)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(on ? Theme.group(g) : Color.white.opacity(0.1), in: Capsule())
                            .foregroundStyle(on ? Theme.bg : Theme.text)
                            .scaleEffect(on ? 1.05 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 16)
        }
        .animation(.bouncy, value: selected)
    }
}

// MARK: - One contest, split screen

struct ContestPage: View {
    let contest: Contest
    let onPick: (Candidate) -> Void
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // TOP HALF — the race, loud
                VStack(alignment: .leading, spacing: 12) {
                    Spacer(minLength: 0)
                    Text(contest.office)
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .white, Theme.group(contest.group)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Theme.group(contest.group).opacity(0.9), radius: 0, x: 3, y: 3)
                        .shadow(color: Theme.group(contest.group).opacity(0.5), radius: 30)
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                    HStack(spacing: 8) {
                        Circle().fill(Theme.group(contest.group)).frame(width: 8, height: 8)
                            .shadow(color: Theme.group(contest.group), radius: 6)
                        Text(subtitle)
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Theme.group(contest.group))
                    }
                    .padding(.bottom, 8)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: geo.size.height * 0.45)
                .offset(y: shown ? 0 : -30)
                .opacity(shown ? 1 : 0)

                // BOTTOM HALF — the people, as stickers
                ZStack {
                    RoundedRectangle(cornerRadius: 36)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 36)
                                .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1)
                        )
                    if contest.candidates.isEmpty {
                        EmptyStage(text: contest.note ?? "Nobody's here yet.", color: Theme.group(contest.group))
                    } else {
                        CandidateStickers(candidates: contest.candidates, shown: shown, onPick: onPick)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .offset(y: shown ? 0 : 60)
                .opacity(shown ? 1 : 0)
            }
        }
        .onAppear { withAnimation(.bouncy(duration: 0.6)) { shown = true } }
        .onDisappear { shown = false }
    }

    private var subtitle: String {
        switch contest.candidates.count {
        case 0: "—"
        case 1: "1 IN THE RING. UNOPPOSED."
        case let n: "\(n) IN THE RING"
        }
    }
}

struct CandidateStickers: View {
    let candidates: [Candidate]
    let shown: Bool
    let onPick: (Candidate) -> Void

    private let cols = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(Array(candidates.enumerated()), id: \.element.id) { i, c in
                    Button {
                        Haptic.tap()
                        onPick(c)
                    } label: {
                        CandidateChip(candidate: c)
                    }
                    .buttonStyle(SquishButton())
                    .floating(phase: Double(i))
                    .scaleEffect(shown ? 1 : 0.6)
                    .opacity(shown ? 1 : 0)
                    .animation(.bouncy(duration: 0.55).delay(Double(i) * 0.05), value: shown)
                }
            }
            .padding(16)
        }
    }
}

struct CandidateChip: View {
    let candidate: Candidate
    private var color: Color { Theme.party(candidate.party) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 1.6 + Double(candidate.name.count))
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(candidate.party.short.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(color, in: Capsule())
                        .foregroundStyle(Theme.bg)
                        .shadow(color: color.opacity(0.8), radius: 8)
                    Spacer()
                    if candidate.incumbent { Text("👑").font(.system(size: 15)) }
                    if candidate.writeIn { Text("✍️").font(.system(size: 15)) }
                }
                Spacer(minLength: 6)
                Text(candidate.name)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.55)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05), .clear],
                                             startPoint: .top, endPoint: .center))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(colors: [.white.opacity(0.9), color.opacity(0.3), .white.opacity(0.15)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.35 + 0.35 * pulse), radius: 14 + 10 * pulse, y: 8)
        }
    }
}

// Slow hover, each card out of phase with its neighbors.
struct Floating: ViewModifier {
    let phase: Double
    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            content.offset(y: sin(t * 1.1 + phase * 1.9) * 3.5)
        }
    }
}

extension View {
    func floating(phase: Double) -> some View { modifier(Floating(phase: phase)) }
}

struct EmptyStage: View {
    let text: String, color: Color

    var body: some View {
        VStack(spacing: 10) {
            Text("👀")
                .font(.system(size: 56))
            Text(text)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

struct Sticker: View {
    let text: String, color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .black, design: .rounded))
            .tracking(1.5)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(Theme.bg)
    }
}

struct SquishButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? 2 : 0))
            .animation(.bouncy(duration: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Lava lamp backdrop

struct LavaLamp: View {
    let seed: Double

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate * 0.35 + seed * 1.7
            ZStack {
                Theme.bg
                ForEach(0..<Theme.blobs.count, id: \.self) { i in
                    let k = Double(i) + 1
                    Circle()
                        .fill(Theme.blobs[i].opacity(0.55))
                        .frame(width: 300 + 80 * k.truncatingRemainder(dividingBy: 2))
                        .offset(x: cos(t * 0.9 / k + k) * 170,
                                y: sin(t * 0.7 * k + k * 2) * 260)
                        .blur(radius: 70)
                }
            }
            .animation(.easeInOut(duration: 1.2), value: seed)
        }
    }
}
