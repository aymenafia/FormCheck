import CoreGraphics
import Foundation

/// One sample of the bar's path through space.
struct TrailSample {
    let point: CGPoint      // normalized, top-left origin
    let time: TimeInterval
    let speed: CGFloat      // body-spans per second
}

/// Bar-path tracking: the trail traces where the bar moved, colored by
/// velocity — green when explosive, red where the rep grinds. VBT hardware
/// sells for $300; this is wrists + math.
enum BarTrail {
    /// How long a sample stays visible.
    static let window: TimeInterval = 2.5

    /// Squat carries the bar on the back (≈ neck); deadlift and bench hold it
    /// in the hands (wrists).
    static func barPoint(in pose: PoseFrame, exercise: Exercise) -> CGPoint? {
        if exercise == .squat {
            if let neck = pose.joints[.neck], neck.confidence >= PoseFrame.minConfidence {
                return neck.location
            }
            return pose.shoulderCenter
        }
        return pose.wristCenter
    }

    static func speed(from previous: TrailSample?, to point: CGPoint, at time: TimeInterval,
                      aspect: CGFloat, bodySpan: CGFloat?) -> CGFloat {
        guard let previous, time > previous.time else { return 0 }
        let dx = (point.x - previous.point.x) * aspect
        let dy = point.y - previous.point.y
        return hypot(dx, dy) / max(bodySpan ?? 0.6, 0.2) / (time - previous.time)
    }

    /// Slow grind → red, moderate → yellow, fast → green.
    /// Thresholds in body-spans/second; tune against real footage.
    static func rgb(forSpeed speed: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let t = min(max((speed - 0.08) / 0.45, 0), 1)
        return (r: min(1, 2 * (1 - t)), g: min(1, 2 * t), b: 0.15)
    }
}
