import SwiftUI

// The one home page. Pick where you vote; everything else inherits it.
struct HomeView: View {
    let onPick: (Place) -> Void
    @State private var shown = false

    private let cols = [GridItem(.adaptive(minimum: 72), spacing: 10)]
    private var live: [Place] { Place.all.filter(\.live) }
    private var soon: [Place] { Place.all.filter { !$0.live } }

    var body: some View {
        ZStack {
            LavaLamp(seed: 3)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("RALLY")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(Theme.pink)
                    .shadow(color: Theme.pink, radius: 8)
                    .padding(.top, 18)
                    .padding(.bottom, 10)

                Text("Where do\nyou vote?")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white, Theme.cyan],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: Theme.cyan.opacity(0.9), radius: 0, x: 3, y: 3)
                    .shadow(color: Theme.cyan.opacity(0.5), radius: 30)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 24)
                    .offset(y: shown ? 0 : -24)
                    .opacity(shown ? 1 : 0)

                // Live places — big, glowing, the thing you want to touch
                ForEach(live) { place in
                    Button {
                        Haptic.tap()
                        onPick(place)
                    } label: {
                        HStack(spacing: 14) {
                            Text(place.id)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.bg)
                                .frame(width: 64, height: 64)
                                .background(Theme.lime, in: RoundedRectangle(cornerRadius: 20))
                                .shadow(color: Theme.lime, radius: 14)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(place.name)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                HStack(spacing: 6) {
                                    Circle().fill(Theme.lime).frame(width: 7, height: 7)
                                        .shadow(color: Theme.lime, radius: 6)
                                    Text("NOV 2026 · LIVE")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(Theme.lime)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(LinearGradient(colors: [.white.opacity(0.8), Theme.lime.opacity(0.4), .white.opacity(0.1)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        )
                        .shadow(color: Theme.lime.opacity(0.35), radius: 24, y: 10)
                    }
                    .buttonStyle(SquishButton())
                    .floating(phase: 0)
                    .scaleEffect(shown ? 1 : 0.8)
                    .opacity(shown ? 1 : 0)
                }

                // Everyone else — honest about it
                Text("SOON")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 26)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(soon) { place in
                            Text(place.id)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.dim)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                    .padding(.bottom, 40)
                }
                .mask(
                    LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom)
                )
                .opacity(shown ? 1 : 0)
            }
            .padding(.horizontal, 22)
        }
        .background(Theme.bg)
        .onAppear { withAnimation(.bouncy(duration: 0.7)) { shown = true } }
    }
}
