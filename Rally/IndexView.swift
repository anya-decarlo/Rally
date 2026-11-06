import SwiftUI

// 🧭 THE INDEX — a real self-assessment. No ambush, no timer. Twelve items,
// five options, one position on the gender-views spectrum — plus how far off
// center you landed.
struct IndexView: View {
    @Environment(\.dismiss) private var dismiss

    struct Item {
        let text: String
        let progressive: Bool // agreeing leans progressive?
    }

    static let items: [Item] = [
        .init(text: "Gender is a spectrum rather than a strict binary.", progressive: true),
        .init(text: "Men and women naturally fill different roles in society.", progressive: false),
        .init(text: "Using someone's stated pronouns is basic respect, whatever your beliefs.", progressive: true),
        .init(text: "Society works best when gender roles stay close to the traditional ones.", progressive: false),
        .init(text: "Schools should be able to teach that gender can differ from sex at birth.", progressive: true),
        .init(text: "There are two genders, and biology settles the question.", progressive: false),
        .init(text: "Gender stereotypes do more harm than good.", progressive: true),
        .init(text: "Parents — not schools — should decide what children learn about gender.", progressive: false),
        .init(text: "Gender-affirming healthcare decisions should be left to patients and doctors.", progressive: true),
        .init(text: "Legal gender changes should require medical documentation.", progressive: false),
        .init(text: "A person's gender identity should carry the same legal weight as their sex at birth.", progressive: true),
        .init(text: "Gender differences between boys and girls should be preserved, not flattened.", progressive: false),
    ]

    @State private var idx = 0
    @State private var answers = [Int?](repeating: nil, count: items.count)
    @State private var done = false

    private var raw: Int {
        Self.items.enumerated().reduce(0) { sum, e in
            sum + (answers[e.offset].map { e.element.progressive ? $0 : -$0 } ?? 0)
        }
    }

    private var position: Double { Double(raw + 24) / 48 * 100 } // 0 = traditional, 100 = progressive
    private var allNeutral: Bool { answers.allSatisfy { $0 == 0 } }
    private var extremity: Double { abs(position - 50) / 50 }    // 0 = dead center, 1 = either pole

    private var positionLabel: String {
        switch position {
        case ..<20: "strongly traditional"
        case ..<40: "traditional-leaning"
        case ..<60: "mixed / centrist"
        case ..<80: "progressive-leaning"
        default: "strongly progressive"
        }
    }

    private var convictionLabel: String {
        switch extremity {
        case ..<0.35: "moderate"
        case ..<0.7: "firm"
        default: "extreme"
        }
    }

    var body: some View {
        ZStack {
            LavaLamp(seed: 5, speed: 0.4)
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
                    Sticker("🧭 the index", color: Theme.violet)
                        .rotationEffect(.degrees(-3))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if done {
                    if allNeutral { secretScreen } else { resultScreen }
                } else { quizScreen }
            }
        }
        .background(Theme.bg)
    }

    // MARK: - Quiz

    private var quizScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            HStack {
                if idx > 0 {
                    Button {
                        Haptic.tick()
                        idx -= 1
                    } label: {
                        Text("← back")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(Theme.dim)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("ITEM \(idx + 1) OF \(Self.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.dim)
            }

            Text("“\(Self.items[idx].text)”")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.edge, lineWidth: 1))
                .id(idx)
                .transition(.opacity)

            Spacer()
            ForEach(Array(options.enumerated()), id: \.offset) { i, label in
                answerButton(label: label, value: i - 2)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .animation(.snappy(duration: 0.3), value: idx)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { g in
                    if g.translation.width > 0 && idx > 0 {
                        Haptic.tick()
                        idx -= 1
                    }
                }
        )
    }

    private let options = ["STRONGLY DISAGREE", "DISAGREE", "NEUTRAL", "AGREE", "STRONGLY AGREE"]

    private func answerButton(label: String, value: Int) -> some View {
        let selected = answers[idx] == value
        return Button {
            Haptic.tick()
            answers[idx] = value
            if idx + 1 < Self.items.count {
                idx += 1
            } else {
                withAnimation(.bouncy(duration: 0.4)) { done = true }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .tracking(2)
                .foregroundStyle(selected ? Theme.ink : Theme.paper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? Theme.paper : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.paper.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result

    private var resultScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("YOUR POSITION")
                .font(.system(size: 30, weight: .black, design: .serif))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 16) {
                Text("GENDER VIEWS INDEX")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.dim)

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.violet, Theme.dim, Theme.pink],
                                                 startPoint: .leading, endPoint: .trailing))
                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .white.opacity(0.8), radius: 6)
                            .offset(x: g.size.width * position / 100 - 7)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("TRADITIONAL")
                    Spacer()
                    Text("PROGRESSIVE")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Theme.dim)

                Divider().overlay(Theme.edge)

                Text(positionLabel)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("conviction: \(convictionLabel)")
                    Spacer()
                    Text("index \(Int(position.rounded()))/100")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.edge, lineWidth: 1))

            Text("Self-reported index based on \(Self.items.count) items. Not a clinical instrument — it's you vs. you.")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Haptic.tap()
                idx = 0; answers = [Int?](repeating: nil, count: Self.items.count); done = false
            } label: {
                Text("RETAKE")
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

    // MARK: - Null result — answered NEUTRAL to every single item

    private var secretScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("THE INSTRUMENT\nCOULD NOT SEE YOU")
                .font(.system(size: 34, weight: .black, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text("CLASSIFICATION: NULL RESULT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.violet)
                Text("You declined to give the instrument anything to work with. Perfectly balanced. No signal detected.")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().overlay(Theme.edge)
                HStack {
                    Text("index 50.000")
                    Spacer()
                    Text("variance 0.0")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.violet.opacity(0.6), lineWidth: 1))

            Text("This result is granted to respondents who answered NEUTRAL on every item. Respondents shown this result: you.")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Haptic.tap()
                idx = 0; answers = [Int?](repeating: nil, count: Self.items.count); done = false
            } label: {
                Text("RETAKE")
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
}

#Preview {
    IndexView()
}
