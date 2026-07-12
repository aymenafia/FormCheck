import Foundation

enum FormFault: String, CaseIterable, Identifiable, Hashable {
    // Squat, side view
    case shallowDepth = "Didn't hit depth"
    case excessiveLean = "Too much forward lean"
    // Squat, front view
    case kneeValgus = "Knees caving in"
    case lateralShift = "Shifting to one side"
    // Squat, either view
    case uncontrolledDescent = "Uncontrolled descent"
    // Deadlift
    case hipsRiseEarly = "Hips shooting up early"
    case barDrift = "Bar drifting away"
    case incompleteLockout = "Incomplete lockout"
    // Bench
    case benchPartialRep = "Didn't touch the chest"
    case barBounce = "Bouncing off the chest"
    case benchSoftLockout = "Didn't lock out"

    var id: String { rawValue }

    /// Joints to ring on screen while this fault is happening live.
    var highlightJoints: [Joint] {
        switch self {
        case .kneeValgus: return [.leftKnee, .rightKnee]
        case .excessiveLean, .hipsRiseEarly: return [.leftShoulder, .rightShoulder]
        case .barDrift: return [.leftWrist, .rightWrist]
        default: return []
        }
    }

    /// Short spoken coaching cue.
    var cue: String {
        switch self {
        case .shallowDepth: return "Go deeper."
        case .excessiveLean: return "Chest up."
        case .kneeValgus: return "Push your knees out."
        case .lateralShift: return "Stay centered."
        case .uncontrolledDescent: return "Control the descent."
        case .hipsRiseEarly: return "Chest and hips together."
        case .barDrift: return "Keep the bar close."
        case .incompleteLockout: return "Stand tall at the top."
        case .benchPartialRep: return "Bring it all the way down."
        case .barBounce: return "Touch and press. Don't bounce."
        case .benchSoftLockout: return "Full lockout at the top."
        }
    }
}

struct RepScore: Identifiable {
    let id = UUID()
    let repIndex: Int
    let exercise: Exercise
    let score: Int
    let faults: [FormFault]
    let depthAchieved: Bool
    let eccentricDuration: TimeInterval
    let maxLeanDegrees: Double

    var grade: String { Self.grade(for: score) }

    static func grade(for score: Int) -> String {
        switch score {
        case 90...: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 55..<70: return "D"
        default: return "F"
        }
    }
}

/// One rep tied to its time range in the set recording, for replay export.
struct RepClip: Identifiable {
    let score: RepScore
    /// Consecutive clean reps up to and including this one.
    let streak: Int
    /// Padded time range in the recording's timeline (seconds).
    let start: TimeInterval
    let end: TimeInterval

    var id: UUID { score.id }
    var isExportable: Bool { end > start }
}

struct SetSummary: Identifiable {
    let id = UUID()
    let clips: [RepClip]
    let recording: SessionRecording?

    var reps: [RepScore] { clips.map(\.score) }

    var averageScore: Int {
        reps.isEmpty ? 0 : reps.map(\.score).reduce(0, +) / reps.count
    }

    var grade: String { RepScore.grade(for: averageScore) }

    /// The most frequent fault across the set — the "fix this first" tip.
    var topFix: FormFault? {
        let counts = Dictionary(grouping: reps.flatMap(\.faults)) { $0 }.mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key
    }
}

/// Scores a rep from its metrics. Pure geometry heuristics — no ML, no network.
/// Thresholds are starting points: film yourself and friends to tune them.
struct FormRuleEngine {
    // Squat, side view
    var leanLimitDegrees: Double = 55
    // Squat, front view
    var valgusRatioLimit: CGFloat = 0.85   // knees inside 85% of stance width = caving
    var lateralShiftLimit: CGFloat = 0.25  // hip more than 25% of stance width off-center
    // Squat, either view
    var minEccentricSeconds: TimeInterval = 0.6
    // Deadlift
    var earlyHipRiseRatioLimit: CGFloat = 0.45 // shoulders rising < 45% as fast as hips
    var barDriftLimit: CGFloat = 0.10          // bar > 10% of body span off the ankles
    var lockoutLeanLimit: Double = 20          // still bent over at the "top"
    // Bench
    var benchTouchGapLimit: CGFloat = 0.12       // wrist stopping too high above the chest.
                                                 // A legit touch still reads ~0.05–0.1 (chest
                                                 // thickness + bar radius) — tune on real footage.
    var benchMinEccentricSeconds: TimeInterval = 0.4
    var benchLockoutAngleLimit: Double = 155     // elbow angle at the top; 180° = straight

    func score(_ metrics: RepMetrics) -> RepScore {
        switch metrics.exercise {
        case .squat: return squatScore(metrics)
        case .deadlift: return deadliftScore(metrics)
        case .bench: return benchScore(metrics)
        }
    }

    private func squatScore(_ metrics: RepMetrics) -> RepScore {
        var faults: [FormFault] = []
        var score = 100

        switch metrics.viewMode {
        case .side:
            // Depth is only visible side-on; the front view can't judge it reliably.
            if !metrics.depthAchieved {
                faults.append(.shallowDepth)
                score -= 40
            }
            if metrics.maxTorsoLeanDegrees > leanLimitDegrees {
                faults.append(.excessiveLean)
                score -= 20
            }
        case .front:
            if let ratio = metrics.minKneeSeparationRatio, ratio < valgusRatioLimit {
                faults.append(.kneeValgus)
                score -= 35
            }
            if let shift = metrics.maxLateralShiftRatio, shift > lateralShiftLimit {
                faults.append(.lateralShift)
                score -= 20
            }
        }

        if metrics.eccentricDuration < minEccentricSeconds {
            faults.append(.uncontrolledDescent)
            score -= 10
        }

        return repScore(metrics, score: score, faults: faults)
    }

    /// No depth or tempo rules here: the deadlift "descent" is the setup on
    /// rep 1, and fast lowering is legitimate on touch-and-go reps.
    private func deadliftScore(_ metrics: RepMetrics) -> RepScore {
        var faults: [FormFault] = []
        var score = 100

        if let ratio = metrics.earlyShoulderHipRatio, ratio < earlyHipRiseRatioLimit {
            faults.append(.hipsRiseEarly)
            score -= 30
        }
        if let drift = metrics.maxBarDriftRatio, drift > barDriftLimit {
            faults.append(.barDrift)
            score -= 25
        }
        if let lean = metrics.lockoutLeanDegrees, lean > lockoutLeanLimit {
            faults.append(.incompleteLockout)
            score -= 20
        }

        return repScore(metrics, score: score, faults: faults)
    }

    /// Bench: baseline/bottom are wrist (bar) heights. Lying face-up with a
    /// top-left origin, the chest is at the shoulder joint's y, and the bar at
    /// its lowest should be near it.
    private func benchScore(_ metrics: RepMetrics) -> RepScore {
        var faults: [FormFault] = []
        var score = 100

        if let shoulderY = metrics.shoulderYAtBottom, shoulderY - metrics.bottomY > benchTouchGapLimit {
            faults.append(.benchPartialRep)
            score -= 35
        }
        if metrics.eccentricDuration < benchMinEccentricSeconds {
            faults.append(.barBounce)
            score -= 20
        }
        if let angle = metrics.lockoutElbowAngleDegrees, angle < benchLockoutAngleLimit {
            faults.append(.benchSoftLockout)
            score -= 20
        }

        return repScore(metrics, score: score, faults: faults)
    }

    private func repScore(_ metrics: RepMetrics, score: Int, faults: [FormFault]) -> RepScore {
        RepScore(
            repIndex: metrics.index,
            exercise: metrics.exercise,
            score: max(score, 0),
            faults: faults,
            depthAchieved: metrics.depthAchieved,
            eccentricDuration: metrics.eccentricDuration,
            maxLeanDegrees: metrics.maxTorsoLeanDegrees
        )
    }
}
