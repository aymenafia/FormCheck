import Foundation

/// Trophies earned from local set history. Pure function of history, so
/// nothing new to persist except which ones the user has already celebrated.
enum Badge: String, CaseIterable, Identifiable {
    case firstSet, firstA, perfectSet, streak3, streak7, cleanTen,
         reps100, reps500, allLifts, sets25, comeback, earlyBird

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSet: return "First Rep"
        case .firstA: return "Straight A"
        case .perfectSet: return "Flawless"
        case .streak3: return "On a Roll"
        case .streak7: return "Iron Week"
        case .cleanTen: return "Clean Ten"
        case .reps100: return "Century"
        case .reps500: return "Rep Machine"
        case .allLifts: return "Full Toolkit"
        case .sets25: return "Regular"
        case .comeback: return "Comeback"
        case .earlyBird: return "Early Bird"
        }
    }

    var detail: String {
        switch self {
        case .firstSet: return "Finish your first scored set"
        case .firstA: return "Score an A on any set"
        case .perfectSet: return "Every rep clean, 5+ reps"
        case .streak3: return "Train 3 days in a row"
        case .streak7: return "Train 7 days in a row"
        case .cleanTen: return "10 clean reps in a row"
        case .reps100: return "Log 100 scored reps"
        case .reps500: return "Log 500 scored reps"
        case .allLifts: return "Try all 4 lifts"
        case .sets25: return "Finish 25 sets"
        case .comeback: return "Jump 2+ grades on the same lift"
        case .earlyBird: return "Finish a set before 8 am"
        }
    }

    var symbol: String {
        switch self {
        case .firstSet: return "figure.strengthtraining.traditional"
        case .firstA: return "star.fill"
        case .perfectSet: return "sparkles"
        case .streak3: return "flame.fill"
        case .streak7: return "flame.circle.fill"
        case .cleanTen: return "checkmark.seal.fill"
        case .reps100: return "100.circle.fill"
        case .reps500: return "bolt.fill"
        case .allLifts: return "square.grid.2x2.fill"
        case .sets25: return "calendar"
        case .comeback: return "arrow.up.right.circle.fill"
        case .earlyBird: return "sunrise.fill"
        }
    }
}

enum Achievements {
    private static let seenKey = "badges.celebrated"

    static func unlocked(in records: [SetRecord]) -> Set<Badge> {
        guard !records.isEmpty else { return [] }
        var out: Set<Badge> = [.firstSet]
        let reps = records.flatMap(\.reps)
        if records.contains(where: { $0.grade == "A" }) { out.insert(.firstA) }
        if records.contains(where: { $0.reps.count >= 5 && $0.reps.allSatisfy(\.isClean) }) { out.insert(.perfectSet) }
        if records.contains(where: { $0.bestStreak >= 10 }) { out.insert(.cleanTen) }
        if reps.count >= 100 { out.insert(.reps100) }
        if reps.count >= 500 { out.insert(.reps500) }
        if Set(records.map(\.exercise)).isSuperset(of: Exercise.available.map(\.rawValue)) { out.insert(.allLifts) }
        if records.count >= 25 { out.insert(.sets25) }
        if records.contains(where: { Calendar.current.component(.hour, from: $0.date) < 8 }) { out.insert(.earlyBird) }

        let streak = longestDayStreak(records)
        if streak >= 3 { out.insert(.streak3) }
        if streak >= 7 { out.insert(.streak7) }

        // Comeback: a later set on the same lift scores 2+ grade steps higher.
        let order = ["F", "D", "C", "B", "A"]
        for (_, sets) in Dictionary(grouping: records, by: \.exercise) {
            var worst = Int.max
            for r in sets.reversed() { // chronological
                let g = order.firstIndex(of: r.grade) ?? 0
                if g - worst >= 2 { out.insert(.comeback); break }
                worst = min(worst, g)
            }
        }
        return out
    }

    static func longestDayStreak(_ records: [SetRecord]) -> Int {
        let cal = Calendar.current
        let days = Set(records.map { cal.startOfDay(for: $0.date) }).sorted()
        var best = 0, run = 0
        var prev: Date?
        for d in days {
            if let p = prev, cal.dateComponents([.day], from: p, to: d).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run)
            prev = d
        }
        return best
    }

    /// Badges unlocked but not yet celebrated; marks them celebrated.
    static func consumeNew(records: [SetRecord]) -> [Badge] {
        let seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        let unlocked = unlocked(in: records)
        let fresh = Badge.allCases.filter { unlocked.contains($0) && !seen.contains($0.rawValue) }
        if !fresh.isEmpty {
            UserDefaults.standard.set(Array(seen.union(fresh.map(\.rawValue))), forKey: seenKey)
        }
        return fresh
    }
}
