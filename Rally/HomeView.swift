import SwiftUI

// The one home page. Pick where you vote; everything else inherits it.
struct HomeView: View {
    let onPick: (Place) -> Void
    @State private var shown = false

    private let cols = [GridItem(.adaptive(minimum: 72), spacing: 10)]
    private var soon: [Place] { Place.all }

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

                // The grid — live, explorable, and honest about the rest
                Text("PICK A PLACE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 26)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(soon) { place in
                            let tappable = place.live || place.explorable
                            let color: Color = place.live ? Theme.lime
                                : place.explorable ? Theme.violet : Theme.dim
                            Button {
                                if tappable {
                                    Haptic.tap()
                                    onPick(place)
                                }
                            } label: {
                                Text(place.id)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(color)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(tappable ? color.opacity(0.15) : .white.opacity(0.06),
                                                in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .stroke(tappable ? color.opacity(0.6) : .white.opacity(0.08),
                                                lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(!tappable)
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
