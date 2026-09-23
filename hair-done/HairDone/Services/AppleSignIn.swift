import Foundation
import CryptoKit
import AuthenticationServices

/// What Sign in with Apple hands back, ready for the backend. The name and email only come the
/// first time she signs in, so they're kept as soon as they arrive.
struct AppleCredential {
    var idToken: String
    /// The nonce before hashing. Its SHA-256 went into the Apple request; the server checks the two match.
    var rawNonce: String
    var firstName: String
    var lastName: String
    var email: String
}

extension AppleCredential {
    init?(authorization: ASAuthorization, rawNonce: String) {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = apple.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else { return nil }
        self.init(
            idToken: token,
            rawNonce: rawNonce,
            firstName: apple.fullName?.givenName ?? "",
            lastName: apple.fullName?.familyName ?? "",
            email: apple.email ?? ""
        )
    }
}

enum AppleNonce {
    /// A random string for one sign-in. `randomElement()` uses the system's secure generator.
    static func make(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var out = ""
        for _ in 0..<length {
            if let c = characters.randomElement() { out.append(c) }
        }
        return out
    }

    /// Lowercase hex SHA-256, which is what goes in `ASAuthorizationAppleIDRequest.nonce`.
    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
