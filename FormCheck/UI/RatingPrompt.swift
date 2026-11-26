import StoreKit
import SwiftUI

/// Native App Store rating prompt, shown at a moment of delight: right after a
/// good set (A or B), including the very first one. Free users only get one
/// set a day, so the old "after 3 sets, once ever" rule meant almost nobody
/// was asked. Re-asks at most every 45 days; Apple additionally caps the
/// system prompt at 3 times per year.
enum RatingPrompt {
    private static let lastAskedKey = "rating.lastAsked"
    private static let reaskInterval: TimeInterval = 45 * 86_400

    static func shouldAsk(for summary: SetSummary) -> Bool {
        guard !summary.clips.isEmpty, !summary.isFreestyle,
              summary.grade == "A" || summary.grade == "B" else { return false }
        let last = UserDefaults.standard.double(forKey: lastAskedKey)
        return last == 0 || Date().timeIntervalSince1970 - last > reaskInterval
    }

    static func markAsked() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastAskedKey)
    }
}
