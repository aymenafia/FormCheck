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
    /// Paste the deployed relay URL, e.g.
    /// `URL(string: "https://formcheck-relay.<you>.workers.dev/install/<INSTALL_SECRET>")`
    static let endpoint: URL? = nil

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
