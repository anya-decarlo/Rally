import SwiftUI

struct ContentView: View {
    @AppStorage("place") private var placeID = ""

    private var place: Place? { Place.find(placeID) }

    var body: some View {
        ZStack {
            if let place {
                StoriesView(place: place) { placeID = "" }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
            } else {
                HomeView { placeID = $0.id }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .animation(.snappy(duration: 0.45), value: placeID)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
