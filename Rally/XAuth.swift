import AuthenticationServices
import CryptoKit
import Foundation

// Connect your X account — OAuth 2.0 + PKCE, the user's own login sheet.
// We never see a password; X hands back a scoped token kept in the Keychain.
//
// One-time setup (developer.x.com → your account → Projects & Apps):
//   1. Create an app, user auth type "Native App" (public client, PKCE)
//   2. Callback URI: rally://x-callback
//   3. Permissions: Read and write (tweet.write powers "share to X")
//   4. Paste the OAuth 2.0 Client ID below.

@Observable
final class XAccount {
    static let clientID = "PASTE_OAUTH2_CLIENT_ID"
    static let callback = "rally://x-callback"
    static let scopes = "tweet.read tweet.write users.read offline.access"

    private(set) var handle: String? = nil          // connected user's @handle
    private(set) var userID: String? = nil
    private(set) var name: String? = nil
    var isConnecting = false
    var lastError: String? = nil

    var isConnected: Bool { handle != nil }
    var isConfigured: Bool { Self.clientID != "PASTE_OAUTH2_CLIENT_ID" }

    private var access: String? = nil
    private var refresh: String? = nil
    private var expiry: Date = .distantPast

    private enum K { static let access = "rally.x.access", refresh = "rally.x.refresh",
                            expiry = "rally.x.expiry", handle = "rally.x.handle",
                            name = "rally.x.name", uid = "rally.x.uid" }

    init() {
        access = Keychain.read(K.access)
        refresh = Keychain.read(K.refresh)
        if let t = UserDefaults.standard.object(forKey: K.expiry) as? Date { expiry = t }
        handle = UserDefaults.standard.string(forKey: K.handle)
        name = UserDefaults.standard.string(forKey: K.name)
        userID = UserDefaults.standard.string(forKey: K.uid)
        if access == nil { disconnect(keepIdentity: false) }
    }

    // MARK: connect

    @MainActor
    func connect() async {
        guard isConfigured else { lastError = "add your X client ID in XAuth.swift first"; return }
        isConnecting = true
        lastError = nil
        defer { isConnecting = false }
        do {
            let code = try await runAuthSession()
            try await exchange(code: code)
            try await loadMe()
            Haptic.tick()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    private func runAuthSession() async throws -> String {
        let verifier = Self.verifier()
        Self.pendingVerifier = verifier
        var c = URLComponents(string: "https://x.com/i/oauth2/authorize")!
        c.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: Self.callback),
            .init(name: "scope", value: Self.scopes),
            .init(name: "state", value: "rally"),
            .init(name: "code_challenge", value: Self.challenge(verifier)),
            .init(name: "code_challenge_method", value: "S256"),
        ]
        return try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: c.url!, callbackURLScheme: "rally") { url, err in
                if let err { cont.resume(throwing: err); return }
                guard let url, let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    cont.resume(throwing: AuthError.noCode); return
                }
                cont.resume(returning: code)
            }
            session.presentationContextProvider = AnchorProvider.shared
            session.prefersEphemeralWebBrowserSession = false   // reuse X's Safari login if present
            session.start()
        }
    }

    private static var pendingVerifier: String?

    private static func verifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func challenge(_ v: String) -> String {
        Data(SHA256.hash(data: Data(v.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: token exchange + refresh

    private func exchange(code: String) async throws {
        guard let verifier = Self.pendingVerifier else { throw AuthError.noCode }
        let res = try await tokenRequest([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.callback,
            "client_id": Self.clientID,
            "code_verifier": verifier,
        ])
        try store(res)
    }

    private func ensureToken() async throws -> String {
        if let access, expiry > .now.addingTimeInterval(60) { return access }
        guard let refresh else { disconnect(); throw AuthError.noToken }
        let res = try await tokenRequest([
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": Self.clientID,
        ])
        try store(res)
        guard let t = self.access else { throw AuthError.noToken }
        return t
    }

    private func tokenRequest(_ form: [String: String]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "https://api.x.com/2/oauth2/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = form.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&").data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.tokenFailed
        }
        return json
    }

    private func store(_ res: [String: Any]) throws {
        guard let a = res["access_token"] as? String else { throw AuthError.tokenFailed }
        access = a
        refresh = res["refresh_token"] as? String ?? refresh
        expiry = .now.addingTimeInterval(res["expires_in"] as? TimeInterval ?? 7200)
        Keychain.write(a, for: K.access)
        if let r = refresh { Keychain.write(r, for: K.refresh) }
        UserDefaults.standard.set(expiry, forKey: K.expiry)
    }

    private func loadMe() async throws {
        let t = try await ensureToken()
        var req = URLRequest(url: URL(string: "https://api.x.com/2/users/me?user.fields=profile_image_url")!)
        req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = json["data"] as? [String: Any] else { throw AuthError.meFailed }
        handle = d["username"] as? String
        name = d["name"] as? String
        userID = d["id"] as? String
        UserDefaults.standard.set(handle, forKey: K.handle)
        UserDefaults.standard.set(name, forKey: K.name)
        UserDefaults.standard.set(userID, forKey: K.uid)
    }

    // MARK: share a receipt as a post

    @discardableResult
    func postReceipt(_ text: String) async throws -> String {
        let t = try await ensureToken()
        var req = URLRequest(url: URL(string: "https://api.x.com/2/tweets")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["text": text])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 201,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = json["data"] as? [String: Any], let id = d["id"] as? String else {
            throw AuthError.postFailed
        }
        return "https://x.com/\(handle ?? "i")/status/\(id)"
    }

    func disconnect(keepIdentity: Bool = true) {
        access = nil; refresh = nil; expiry = .distantPast
        Keychain.delete(K.access); Keychain.delete(K.refresh)
        UserDefaults.standard.removeObject(forKey: K.expiry)
        if !keepIdentity {
            handle = nil; name = nil; userID = nil
            [K.handle, K.name, K.uid].forEach { UserDefaults.standard.removeObject(forKey: $0) }
        }
    }

    enum AuthError: LocalizedError {
        case noCode, noToken, tokenFailed, meFailed, postFailed
        var errorDescription: String? {
            switch self {
            case .noCode: "sign-in didn't return a code"
            case .noToken: "not connected"
            case .tokenFailed: "token exchange failed"
            case .meFailed: "couldn't read your profile"
            case .postFailed: "post failed"
            }
        }
    }
}

// MARK: - plumbing

final class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AnchorProvider()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

enum Keychain {
    static func write(_ v: String, for key: String) {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q.merging([kSecValueData: Data(v.utf8)]) { $1 } as CFDictionary, nil)
    }
    static func read(_ key: String) -> String? {
        var q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key,
                                  kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func delete(_ key: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary)
    }
}
