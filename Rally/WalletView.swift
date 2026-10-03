import SwiftUI

// 👛 Everything you pocketed. Sources intact. Share one or share the lot.
struct WalletView: View {
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var shareAll: String {
        wallet.byCandidate.map { name, items in
            "\(name.uppercased())\n" + items.map { "• \($0.title): \($0.text.replacingOccurrences(of: "\n", with: " · "))\n  \($0.url?.absoluteString ?? "")" }.joined(separator: "\n")
        }.joined(separator: "\n\n") + "\n\n— my receipts, via Rally"
    }

    var body: some View {
        ZStack {
            LavaLamp(seed: 23).ignoresSafeArea()
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
                    Sticker("👛 Your receipts", color: Theme.yellow).rotationEffect(.degrees(-2))
                    Spacer()
                    if !wallet.items.isEmpty {
                        ShareLink(item: shareAll) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .black))
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                                .foregroundStyle(.white)
                        }
                    } else {
                        Color.clear.frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if wallet.items.isEmpty {
                    EmptyStage(text: "Nothing pocketed yet.\nSwipe right on anything in a feed to keep it.", color: Theme.yellow)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            Text("\(wallet.items.count) receipt\(wallet.items.count == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Theme.dim)
                                .padding(.top, 10)
                            ForEach(wallet.byCandidate, id: \.0) { name, items in
                                Text(name.uppercased())
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .tracking(2)
                                    .foregroundStyle(.white)
                                    .padding(.top, 6)
                                ForEach(items) { item in
                                    SavedCard(item: item)
                                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                                }
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .background(Theme.bg)
    }
}

struct SavedCard: View {
    let item: SavedItem
    @Environment(Wallet.self) private var wallet
    @Environment(\.openURL) private var openURL

    private var color: Color {
        switch item.category {
        case "money": Theme.lime
        case "vote": Theme.pink
        case "bio": Theme.yellow
        case "endorsement": Theme.orange
        case "identity": Theme.violet
        case "post": Theme.cyan
        default: Theme.cyan
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(color).brightness(-0.25)
                Spacer()
                Button {
                    Haptic.tick()
                    withAnimation(.bouncy) { wallet.remove(item.id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            Text(item.text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let url = item.url {
                    Button { openURL(url) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text(item.source.uppercased()).lineLimit(1)
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                ShareLink(item: "\(item.title): \(item.text)\n\(item.url?.absoluteString ?? "")\n— via Rally") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                }
            }
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4).padding(.vertical, 10).padding(.leading, 4)
        }
        .shadow(color: color.opacity(0.25), radius: 10, y: 4)
    }
}

// The wallet button that lives in feed/story headers. Bounces when something lands in it.
struct WalletButton: View {
    @Environment(Wallet.self) private var wallet
    @State private var show = false
    @State private var bump = false

    var body: some View {
        Button {
            Haptic.tick()
            show = true
        } label: {
            HStack(spacing: 5) {
                Text("👛")
                if !wallet.items.isEmpty {
                    Text("\(wallet.items.count)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(bump ? Theme.yellow : .white.opacity(0.25), lineWidth: bump ? 2 : 1))
            .scaleEffect(bump ? 1.25 : 1)
            .shadow(color: Theme.yellow.opacity(bump ? 0.9 : 0), radius: 14)
        }
        .buttonStyle(.plain)
        .onChange(of: wallet.lastSavedID) {
            withAnimation(.bouncy(duration: 0.35, extraBounce: 0.3)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { withAnimation(.bouncy) { bump = false } }
        }
        .fullScreenCoverCompat(isPresented: $show) { WalletView() }
    }
}
