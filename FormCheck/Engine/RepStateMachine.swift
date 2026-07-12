import CoreGraphics
import Foundation

enum RepPhase: String {
    case calibrating = "Hold still…"
    case standing = "Ready"
    case descending = "Down"
    case ascending = "Up"
}

/// Everything measured during one rep, consumed by the rule engine.
struct RepMetrics {
    let index: Int
    let exercise: Exercise
    let viewMode: ViewMode
    let startTime: TimeInterval
    let bottomTime: TimeInterval
    let endTime: TimeInterval
    /// Tracked-joint height at rest: hips at standing (squat/deadlift) or
    /// wrists at lockout (bench).
    let baselineY: CGFloat
    /// Deepest tracked-joint position during the rep.
    let bottomY: CGFloat
    let kneeYAtBottom: CGFloat?
    /// Bench: shoulder (chest) height at the bar's lowest point.
    let shoulderYAtBottom: CGFloat?
    let maxTorsoLeanDegrees: Double
    /// Bench: elbow extension at the rep-completion frame (180° = locked out).
    let lockoutElbowAngleDegrees: Double?
    /// Front view only: lowest knee/ankle separation ratio during the rep.
    let minKneeSeparationRatio: CGFloat?
    /// Front view only: largest hip shift off-center, as a fraction of stance width.
    let maxLateralShiftRatio: CGFloat?
    /// Deadlift only: shoulder rise / hip rise in the early pull.
    /// Near 1 = moving together; near 0 = hips shooting up first.
    let earlyShoulderHipRatio: CGFloat?
    /// Deadlift only: max wrist-to-ankle horizontal offset during the pull,
    /// as a fraction of standing body span (bar-path proxy).
    let maxBarDriftRatio: CGFloat?
    /// Deadlift only: torso lean at the lockout frame.
    let lockoutLeanDegrees: Double?

    var eccentricDuration: TimeInterval { bottomTime - startTime }
    var concentricDuration: TimeInterval { endTime - bottomTime }

    /// Squat parallel ≈ hip joint level with the knee joint in the image.
    /// Top-left origin, so a larger y means lower in frame.
    var depthAchieved: Bool {
        guard let kneeY = kneeYAtBottom else { return false }
        return bottomY >= kneeY - 0.02
    }
}

/// Tracks hip height through standing → descending → ascending → lockout.
/// Calibrates standing hip height over the first frames, then detects reps
/// with hysteresis thresholds so pose jitter can't produce phantom reps.
final class RepStateMachine {
    private(set) var phase: RepPhase = .calibrating
    private(set) var repCount = 0
    var viewMode: ViewMode = .side
    var exercise: Exercise = .squat

    var onRepCompleted: ((RepMetrics) -> Void)?
    var onPhaseChanged: ((RepPhase) -> Void)?

    // Tunables, in normalized image-height units.
    private let descentThreshold: CGFloat = 0.05   // hip drop that starts a rep
    private let lockoutThreshold: CGFloat = 0.025  // distance from standing that ends a rep
    private let turnaroundThreshold: CGFloat = 0.02 // rise off the bottom that flips to ascending
    private let calibrationFrames = 30
    private let calibrationStillness: CGFloat = 0.025 // max drift allowed across the calibration window
    private let teleportThreshold: CGFloat = 0.12 // > this per frame = tracking glitch, not movement

    private var calibrationSamples: [CGFloat] = []
    private var standingHipY: CGFloat = 0
    private var standingBodySpan: CGFloat?

    private var repStartTime: TimeInterval = 0
    private var bottomTime: TimeInterval = 0
    private var bottomHipY: CGFloat = 0
    private var kneeYAtBottom: CGFloat?
    private var maxLean: Double = 0
    private var minKneeSeparation: CGFloat?
    private var maxLateralShift: CGFloat = 0
    private var bottomShoulderY: CGFloat?
    private var minEarlyShoulderHipRatio: CGFloat?
    private var maxBarDrift: CGFloat?
    private var lastTrackedY: CGFloat?
    private var outlierStreak = 0

    func reset() {
        setPhase(.calibrating)
        repCount = 0
        calibrationSamples = []
        standingHipY = 0
        standingBodySpan = nil
        lastTrackedY = nil
        outlierStreak = 0
    }

    /// Live internals for the debug overlay.
    var debugSnapshot: String {
        String(format: "base %.3f  bottom %.3f", standingHipY, bottomHipY)
    }

    /// Standing body span captured at calibration — the size reference for
    /// live bar-drift checks.
    var calibratedBodySpan: CGFloat? { standingBodySpan }

    func process(_ frame: PoseFrame) {
        // Bench follows the bar (wrists); squat and deadlift follow the hips.
        let tracked = exercise.tracksWrists ? frame.wristCenter : frame.hipCenter
        guard let hipY = tracked?.y else { return }

        // A joint can't legitimately move 12% of the frame in one frame
        // (~7 m/s) — that's a tracking glitch. Ignore up to 3 such frames;
        // if it persists, accept the new position as reality.
        if let last = lastTrackedY, abs(hipY - last) > teleportThreshold, outlierStreak < 3 {
            outlierStreak += 1
            return
        }
        outlierStreak = 0
        lastTrackedY = hipY

        if phase == .descending || phase == .ascending {
            switch viewMode {
            case .side:
                if let lean = frame.torsoLeanDegrees {
                    maxLean = max(maxLean, lean)
                }
            case .front:
                if let ratio = frame.kneeSeparationRatio {
                    minKneeSeparation = min(minKneeSeparation ?? ratio, ratio)
                }
                if let shift = frame.lateralShiftRatio {
                    maxLateralShift = max(maxLateralShift, abs(shift))
                }
            }
            if exercise == .deadlift, phase == .ascending {
                accumulateDeadliftPull(frame, hipY: hipY)
            }
        }

        switch phase {
        case .calibrating:
            // Bench: only calibrate the lockout height while the arms are
            // actually extended, so racked/unracking positions don't pollute it.
            if exercise.tracksWrists, (frame.maxElbowExtensionDegrees ?? 0) < 150 {
                break
            }
            calibrationSamples.append(hipY)
            if let span = frame.bodySpan {
                standingBodySpan = span
            }
            // Sliding window: the baseline locks only once a full window of
            // frames is genuinely still — walking into position can't set it.
            if calibrationSamples.count > calibrationFrames {
                calibrationSamples.removeFirst()
            }
            if calibrationSamples.count == calibrationFrames {
                let sorted = calibrationSamples.sorted()
                if sorted[sorted.count - 1] - sorted[0] < calibrationStillness {
                    standingHipY = sorted[sorted.count / 2]
                    setPhase(.standing)
                }
            }

        case .standing:
            if hipY > standingHipY + descentThreshold {
                repStartTime = frame.timestamp
                bottomTime = frame.timestamp
                bottomHipY = hipY
                kneeYAtBottom = frame.mostConfidentKneeY
                maxLean = frame.torsoLeanDegrees ?? 0
                minKneeSeparation = frame.kneeSeparationRatio
                maxLateralShift = abs(frame.lateralShiftRatio ?? 0)
                bottomShoulderY = frame.shoulderCenter?.y
                minEarlyShoulderHipRatio = nil
                maxBarDrift = nil
                setPhase(.descending)
            } else {
                // Slowly track drift (user shifting stance / camera settling).
                standingHipY = standingHipY * 0.95 + hipY * 0.05
            }

        case .descending:
            if hipY >= bottomHipY {
                bottomHipY = hipY
                bottomTime = frame.timestamp
                kneeYAtBottom = frame.mostConfidentKneeY
                bottomShoulderY = frame.shoulderCenter?.y
            } else if bottomHipY - hipY > turnaroundThreshold {
                setPhase(.ascending)
            }

        case .ascending:
            if hipY > bottomHipY {
                // Went back down past the previous bottom — still the same rep.
                bottomHipY = hipY
                bottomTime = frame.timestamp
                kneeYAtBottom = frame.mostConfidentKneeY
                bottomShoulderY = frame.shoulderCenter?.y
                setPhase(.descending)
            } else if hipY < standingHipY + lockoutThreshold {
                repCount += 1
                let metrics = RepMetrics(
                    index: repCount,
                    exercise: exercise,
                    viewMode: viewMode,
                    startTime: repStartTime,
                    bottomTime: bottomTime,
                    endTime: frame.timestamp,
                    baselineY: standingHipY,
                    bottomY: bottomHipY,
                    kneeYAtBottom: kneeYAtBottom,
                    shoulderYAtBottom: bottomShoulderY,
                    maxTorsoLeanDegrees: maxLean,
                    lockoutElbowAngleDegrees: frame.maxElbowExtensionDegrees,
                    minKneeSeparationRatio: minKneeSeparation,
                    maxLateralShiftRatio: maxLateralShift,
                    earlyShoulderHipRatio: minEarlyShoulderHipRatio,
                    maxBarDriftRatio: maxBarDrift,
                    lockoutLeanDegrees: frame.torsoLeanDegrees
                )
                setPhase(.standing)
                onRepCompleted?(metrics)
            }
        }
    }

    /// Deadlift pull analysis, sampled while ascending.
    /// Early pull (first half of hip travel): shoulders should rise with the
    /// hips — a collapsing ratio means the lifter is turning it into a
    /// stiff-leg heave. Whole pull: the wrists (bar proxy) should stay over
    /// the ankles.
    private func accumulateDeadliftPull(_ frame: PoseFrame, hipY: CGFloat) {
        let hipRise = bottomHipY - hipY
        let pullRange = max(bottomHipY - standingHipY, 0.01)
        if hipRise > 0.03, hipRise < pullRange * 0.5,
           let bottomShoulderY, let shoulder = frame.shoulderCenter {
            let ratio = (bottomShoulderY - shoulder.y) / hipRise
            minEarlyShoulderHipRatio = min(minEarlyShoulderHipRatio ?? ratio, ratio)
        }
        if let wrist = frame.wristCenter, let ankle = frame.ankleCenter,
           let span = standingBodySpan {
            let drift = abs(wrist.x - ankle.x) * frame.imageAspect / span
            maxBarDrift = max(maxBarDrift ?? drift, drift)
        }
    }

    private func setPhase(_ new: RepPhase) {
        guard new != phase else { return }
        phase = new
        onPhaseChanged?(new)
    }
}
