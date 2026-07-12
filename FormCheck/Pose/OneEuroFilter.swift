import CoreGraphics
import Foundation

/// One Euro filter (Casiez et al.) — smooths jitter at low speeds while staying
/// responsive during fast movement. The standard choice for pose landmarks.
final class OneEuroFilter {
    private let minCutoff: Double
    private let beta: Double
    private let derivativeCutoff: Double

    private var lastValue: Double?
    private var lastDerivative: Double = 0
    private var lastTime: TimeInterval?

    init(minCutoff: Double = 1.0, beta: Double = 0.3, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    func filter(_ value: Double, at time: TimeInterval) -> Double {
        guard let previousValue = lastValue, let previousTime = lastTime, time > previousTime else {
            lastValue = value
            lastTime = time
            return value
        }
        let dt = time - previousTime
        let rawDerivative = (value - previousValue) / dt
        let dAlpha = Self.alpha(cutoff: derivativeCutoff, dt: dt)
        let derivative = dAlpha * rawDerivative + (1 - dAlpha) * lastDerivative

        let cutoff = minCutoff + beta * abs(derivative)
        let a = Self.alpha(cutoff: cutoff, dt: dt)
        let filtered = a * value + (1 - a) * previousValue

        lastValue = filtered
        lastDerivative = derivative
        lastTime = time
        return filtered
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * .pi * cutoff)
        return 1 / (1 + tau / dt)
    }
}

/// Applies a One Euro filter per joint axis across successive pose frames.
final class PoseSmoother {
    private var filters: [Joint: (x: OneEuroFilter, y: OneEuroFilter)] = [:]

    func smooth(_ frame: PoseFrame) -> PoseFrame {
        var smoothed = frame
        for (joint, point) in frame.joints {
            let pair: (x: OneEuroFilter, y: OneEuroFilter)
            if let existing = filters[joint] {
                pair = existing
            } else {
                pair = (x: OneEuroFilter(), y: OneEuroFilter())
                filters[joint] = pair
            }
            smoothed.joints[joint]?.location = CGPoint(
                x: pair.x.filter(Double(point.location.x), at: frame.timestamp),
                y: pair.y.filter(Double(point.location.y), at: frame.timestamp)
            )
        }
        return smoothed
    }

    func reset() {
        filters.removeAll()
    }
}
