import Foundation

/// Optional fire-and-forget "first launch" ping to the FormCheck relay, so a
/// 📲 lands in Discord/Telegram when someone new opens the app.
///
/// PRIVACY: sends no identifiers, no device info, no body — a bare POST that
/// increments a counter, once per install. Even so, enabling this means the
/// app transmits usage data: answer Apple's privacy questionnaire with
/// "Usage Data → Product Interaction, not linked to identity, no tracking"
/// instead of "Data Not Collected".
///
/// DISABLED until `endpoint` is set. Leave it nil to keep the app fully
/// network-silent (StoreKit aside).
enum InstallPing {
    /// Deployed relay. This install secret is semi-public by design (it ships
    /// in the binary and this repo is public); worst case is fake 📲 pings —
    /// rotate INSTALL_SECRET in Cloudflare if that ever happens. The payment
    /// secret is separate and never leaves Cloudflare/ASC.
    static let endpoint: URL? = URL(string: "https://formcheck-relay.aymenafia.workers.dev/install/5a805ee62b84f49ba9e8a41b64f4156f6795cca61b823989")

    private static let sentKey = "installPing.sent"

    static func fireIfNeeded() {
        guard let endpoint, !UserDefaults.standard.bool(forKey: sentKey) else { return }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "env", value: environment)]
        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                // Only mark sent on success — a failed ping retries next launch.
                UserDefaults.standard.set(true, forKey: sentKey)
            }
        }.resume()
    }

    private static var environment: String {
        #if DEBUG
        return "dev"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "beta" // TestFlight
        }
        return "prod"
        #endif
    }
}
