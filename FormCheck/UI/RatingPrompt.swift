import StoreKit
import SwiftUI

/// Native App Store rating prompt, shown at a moment of delight — after the
/// user has completed a few sets and just finished a good one. Never on a
/// failing set, never on first use, and only once. Apple additionally
/// rate-limits the system prompt to 3 times per year.
enum RatingPrompt {
    private static let askedKey = "rating.asked"
    private static let minSets = 3

    /// Whether now is a good moment to ask, given the just-finished set.
    static func shouldAsk(for summary: SetSummary) -> Bool {
        guard !summary.clips.isEmpty, summary.grade != "F" else { return false }
        guard !UserDefaults.standard.bool(forKey: askedKey) else { return false }
        return UserDefaults.standard.integer(forKey: "stats.completedSets") >= minSets
    }

    static func markAsked() {
        UserDefaults.standard.set(true, forKey: askedKey)
    }
}
