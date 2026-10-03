import SwiftUI

// 🌸 THE BOOTH — kawaii stickers on the official portrait. Curated tray only; nothing rude is possible.
struct BoothView: View {
    let candidate: Candidate
    let portrait: Portrait
    @Environment(\.dismiss) private var dismiss
    @State private var stickers: [PlacedSticker] = []
    @State private var exported: Image?
    @State private var flash = false
    private var color: Color { Theme.party(candidate.party) }

    static let tray = ["🌸", "✨", "🎀", "💖", "🐱", "🍡", "☁️", "⭐", "🌈", "🍓", "🫧", "🦋", "🌙", "💫", "🍰", "🐸"]

    var body: some View {
        ZStack {
            LavaLamp(seed: 7)
                .ignoresSafeArea()

            VStack(spacing: 14) {
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
                    Sticker("🌸 The booth", color: Theme.pink)
                        .rotationEffect(.degrees(3))
                    Spacer()
                    Button {
                        Haptic.tick()
                        withAnimation(.bouncy) { stickers.removeAll() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .black))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(stickers.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // canvas
                canvas
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.3), lineWidth: 1.5))
                    .shadow(color: color.opacity(0.5), radius: 30, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28).fill(.white).opacity(flash ? 0.8 : 0)
                    )
                    .padding(.horizontal, 16)

                Text("Tap a sticker to add it · drag to move · pinch & twist")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.dim)

                // tray
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Self.tray, id: \.self) { s in
                            Button {
                                Haptic.tap()
                                withAnimation(.bouncy(duration: 0.4)) {
                                    stickers.append(PlacedSticker(emoji: s,
                                                                  position: CGPoint(x: .random(in: 0.3...0.7), y: .random(in: 0.3...0.7)),
                                                                  rotation: .degrees(.random(in: -20...20))))
                                }
                            } label: {
                                Text(s)
                                    .font(.system(size: 34))
                                    .frame(width: 60, height: 60)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(SquishButton())
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    if let exported {
                        ShareLink(item: exported, preview: SharePreview("\(candidate.name) 🌸 made in Rally", image: exported)) {
                            label("SHARE", "square.and.arrow.up", Theme.cyan)
                        }
                        .buttonStyle(SquishButton())
                    }
                    Button { snap() } label: { label("SNAP", "camera.fill", Theme.pink) }
                        .buttonStyle(SquishButton())
                }
                .padding(.horizontal, 16)

                Text("Portrait: \(portrait.credit) · \(portrait.license)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                    .padding(.bottom, 14)
            }
        }
        .background(Theme.bg)
    }

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                PortraitImage(file: portrait.file)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                ForEach($stickers) { $s in
                    StickerView(sticker: $s, canvas: geo.size)
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("made in Rally 🌸")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.black.opacity(0.35), in: Capsule())
                            .padding(10)
                    }
                }
            }
        }
    }

    private func label(_ t: String, _ icon: String, _ c: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 16, weight: .black))
            Text(t).font(.system(size: 18, weight: .black, design: .rounded))
        }
        .foregroundStyle(Theme.bg)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(c, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: c.opacity(0.6), radius: 18, y: 6)
    }

    @MainActor private func snap() {
        Haptic.tap()
        withAnimation(.easeOut(duration: 0.1)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation { flash = false } }
        let r = ImageRenderer(content: canvas.frame(width: 1080, height: 1080))
        r.scale = 1
        #if os(iOS)
        if let ui = r.uiImage { exported = Image(uiImage: ui) }
        #else
        if let ns = r.nsImage { exported = Image(nsImage: ns) }
        #endif
    }
}

struct PlacedSticker: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGPoint        // normalized 0…1
    var scale: CGFloat = 1
    var rotation: Angle
}

struct StickerView: View {
    @Binding var sticker: PlacedSticker
    let canvas: CGSize
    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var twist: Angle = .zero

    var body: some View {
        Text(sticker.emoji)
            .font(.system(size: 72))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .scaleEffect(sticker.scale * pinch)
            .rotationEffect(sticker.rotation + twist)
            .position(x: sticker.position.x * canvas.width + drag.width,
                      y: sticker.position.y * canvas.height + drag.height)
            .gesture(
                DragGesture()
                    .updating($drag) { v, s, _ in s = v.translation }
                    .onEnded { v in
                        sticker.position.x += v.translation.width / canvas.width
                        sticker.position.y += v.translation.height / canvas.height
                    }
                    .simultaneously(with: MagnifyGesture()
                        .updating($pinch) { v, s, _ in s = v.magnification }
                        .onEnded { v in sticker.scale = max(0.4, min(3, sticker.scale * v.magnification)) })
                    .simultaneously(with: RotateGesture()
                        .updating($twist) { v, s, _ in s = v.rotation }
                        .onEnded { v in sticker.rotation += v.rotation })
            )
    }
}

struct PortraitImage: View {
    let file: String
    var body: some View {
        if let url = Bundle.main.url(forResource: (file as NSString).deletingPathExtension,
                                     withExtension: (file as NSString).pathExtension),
           let data = try? Data(contentsOf: url) {
            #if os(iOS)
            if let ui = UIImage(data: data) { Image(uiImage: ui).resizable() } else { Color.gray }
            #else
            if let ns = NSImage(data: data) { Image(nsImage: ns).resizable() } else { Color.gray }
            #endif
        } else {
            Color.gray
        }
    }
}
