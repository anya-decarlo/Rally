import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

// Mirrors pipeline/schema.md exactly. The app reads only this shape.

struct PostsFile: Codable {
    let generatedAt: String
    let posts: [Post]
}

struct Post: Identifiable, Codable, Hashable {
    let id: String
    let platform: String
    let candidate: String
    let account: Account
    let text: String
    let createdAt: String
    let url: URL
    let media: [Media]
    let metrics: Metrics
    var quoted: Quoted? = nil

    struct Account: Codable, Hashable {
        let handle: String
        let displayName: String
        let avatar: URL?
        let kind: String            // "official" | "personal"
    }
    struct Media: Codable, Hashable {
        let type: String            // "image" | "video" | "link"
        let url: URL?
        var thumb: URL? = nil
        var alt: String? = nil
        var title: String? = nil
    }
    struct Metrics: Codable, Hashable {
        let likes: Int, reposts: Int, replies: Int
    }
    struct Quoted: Codable, Hashable {
        let handle: String, text: String, url: URL
    }

    var date: Date? { ISO8601DateFormatter.parse(createdAt) }
    var isOfficial: Bool { account.kind == "official" }
    var image: Media? { media.first { $0.type == "image" } }
    var video: Media? { media.first { $0.type == "video" } }
    var link: Media? { media.first { $0.type == "link" } }
    var platformLabel: String { platform == "bluesky" ? "Bluesky" : platform == "x" ? "X" : platform }

}

#if canImport(UIKit)
import StoreKit

private let linkLog = Logger(subsystem: "com.anyadecarlo.Rally", category: "links")

// The 🍎 button: opens the App Store. Tries the real App Store app first;
// where that can't open (Simulator has no App Store app), shows the store
// listing as an in-app sheet — never Safari.
func openAppStore() {
    let itms = URL(string: "itms-apps://apps.apple.com/app/id333903271")!
    linkLog.info("[rally:link] 🍎 open \(itms.absoluteString)")
    UIApplication.shared.open(itms) { ok in
        linkLog.info("[rally:link] 🍎 itms-apps → \(ok)")
        if !ok { presentAppStoreListing() }
    }
}

// Opens X's App Store listing as a native in-app sheet — never goes through
// Safari and never fires an itms-apps:// URL that can bounce back as an
// "invalid address" error.
func presentAppStoreListing() {
    linkLog.info("[rally:link] presenting App Store sheet")
    guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
          let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
        linkLog.error("[rally:link] no window for App Store sheet"); return
    }
    let store = SKStoreProductViewController()
    var top = root
    while let p = top.presentedViewController { top = p }
    top.present(store, animated: true)
    store.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: 333903271]) { ok, err in
        linkLog.info("[rally:link] App Store sheet load → \(ok) \(err?.localizedDescription ?? "")")
    }
}

extension Post {
    // X post: try the X app's deep link first; if no X app is installed, show
    // the App Store listing in-app. Anything else opens its canonical URL.
    // We *try* each deep link via open() completion — canOpenURL lies.
    func openLink() {
        guard platform == "x" else {
            linkLog.info("[rally:link] \(self.platform) \(self.id) open \(self.url.absoluteString)")
            UIApplication.shared.open(url)
            return
        }
        let id = url.lastPathComponent
        let deepLinks = ["x://status?id=\(id)", "twitter://status?id=\(id)"]
            .compactMap(URL.init(string:))
        linkLog.info("[rally:link] x \(self.id) deepLinks=\(deepLinks.map(\.absoluteString))")
        func tryNext(_ i: Int) {
            if i >= deepLinks.count {
                linkLog.info("[rally:link] no X app — opening App Store")
                openAppStore()
                return
            }
            UIApplication.shared.open(deepLinks[i]) { ok in
                linkLog.info("[rally:link] open \(deepLinks[i].absoluteString) → \(ok)")
                if !ok { tryNext(i + 1) }
            }
        }
        tryNext(0)
    }
}
#elseif canImport(AppKit)
import AppKit

private let linkLog = Logger(subsystem: "com.anyadecarlo.Rally", category: "links")

// macOS build: macappstore:// opens the real App Store app on the Mac.
func openAppStore() {
    let itms = URL(string: "macappstore://apps.apple.com/app/id333903271")!
    linkLog.info("[rally:link] 🍎 open \(itms.absoluteString)")
    if !NSWorkspace.shared.open(itms) {
        linkLog.error("[rally:link] macappstore failed")
    }
}

extension Post {
    func openLink() {
        guard platform == "x" else {
            linkLog.info("[rally:link] \(self.platform) \(self.id) open \(self.url.absoluteString)")
            NSWorkspace.shared.open(url)
            return
        }
        let id = url.lastPathComponent
        for s in ["x://status?id=\(id)", "twitter://status?id=\(id)"] {
            if let u = URL(string: s), NSWorkspace.shared.open(u) {
                linkLog.info("[rally:link] open \(u.absoluteString) → true")
                return
            }
        }
        linkLog.info("[rally:link] no X app — opening App Store")
        openAppStore()
    }
}
#endif

// Timestamps arrive verbatim from each platform — with or without fractional seconds. Accept both.
extension ISO8601DateFormatter {
    private static let withMillis: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func parse(_ s: String) -> Date? { withMillis.date(from: s) ?? plain.date(from: s) }
}

// posts.json: bundled copy on launch, replaced wholesale by the backend when it answers.
@Observable
final class PostStore {
    private(set) var posts: [Post] = []
    private(set) var generatedAt: String = ""
    private(set) var isLive = false

    init() {
        if let file = PostStore.loadBundled("posts", as: PostsFile.self) { apply(file) }
    }

    func posts(for candidate: Candidate) -> [Post] {
        posts.filter { $0.candidate == candidate.name }
    }

    @MainActor
    func refresh() async {
        guard let file = await Backend.fetch(Backend.posts, as: PostsFile.self) else { return }
        apply(file)
        isLive = true
    }

    // Merge by id — bundled posts for candidates the backend hasn't crawled yet
    // stay in the feed; remote wins on any post it knows about.
    private func apply(_ file: PostsFile) {
        var merged = Dictionary(posts.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for p in file.posts { merged[p.id] = p }
        posts = merged.values.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        generatedAt = file.generatedAt
    }
}
