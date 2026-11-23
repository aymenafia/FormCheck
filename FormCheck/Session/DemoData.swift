#if DEBUG
import Foundation

/// Simulator-only fixtures: the camera doesn't run there, so these let the
/// results, history and trophy screens be exercised and screenshotted.
/// Launch with -seedHistory and/or -demoSummary.
enum DemoData {
    static func seedHistory() {
        guard HistoryStore.shared.records.isEmpty else { return }
        let cal = Calendar.current
        let plan: [(Int, String, [Int])] = [
            (9, "Squat", [62, 58, 70, 55, 66]), (8, "Squat", [70, 74, 68, 72]), (6, "Deadlift", [75, 80, 71]),
            (5, "Squat", [78, 82, 85, 80]), (3, "Overhead Press", [84, 88, 90]), (2, "Squat", [86, 90, 88, 92]),
            (1, "Lunge", [90, 94, 88]),
        ]
        for (daysAgo, lift, scores) in plan {
            let reps = scores.enumerated().map { i, s in
                RepRecord(index: i + 1, score: s, faults: s >= 85 ? [] : [lift == "Deadlift" ? FormFault.barDrift.rawValue : FormFault.excessiveLean.rawValue])
            }
            let avg = scores.reduce(0, +) / scores.count
            HistoryStore.shared.add(SetRecord(id: UUID(), date: cal.date(byAdding: .day, value: -daysAgo, to: Date())!,
                                              exercise: lift, viewMode: "Side", grade: RepScore.grade(for: avg),
                                              averageScore: avg, bestStreak: reps.filter(\.isClean).count, reps: reps))
        }
    }

    static func summary() -> SetSummary {
        let scores: [(Int, [FormFault])] = [(94, []), (96, []), (88, [.excessiveLean]), (97, []), (95, []), (91, []), (93, [])]
        var run = 0
        let clips = scores.enumerated().map { i, item -> RepClip in
            run = item.1.isEmpty ? run + 1 : 0
            let score = RepScore(repIndex: i + 1, exercise: .squat, score: item.0, faults: item.1,
                                 depthAchieved: true, eccentricDuration: 1.2, maxLeanDegrees: 40)
            return RepClip(score: score, streak: run, start: 0, end: 0)
        }
        let summary = SetSummary(clips: clips, recording: nil)
        HistoryStore.shared.add(SetRecord(summary: summary, exercise: .squat, viewMode: .side))
        return summary
    }
}
#endif
