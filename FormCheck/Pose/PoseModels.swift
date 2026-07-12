import CoreGraphics
import Foundation

/// Body joints tracked by the app. Mirrors Vision's body-pose joints, but kept
/// framework-agnostic so the pose backend can be swapped (e.g. MediaPipe on Android).
enum Joint: String, CaseIterable {
    case nose, neck
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case root, leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

struct JointPoint {
    /// Normalized [0, 1] position, origin at the top-left of the upright (portrait) image.
    var location: CGPoint
    var confidence: Float
}

struct PoseFrame {
    var timestamp: TimeInterval
    /// Width / height of the source image, needed for angle math and aspect-fill mapping.
    var imageAspect: CGFloat
    var joints: [Joint: JointPoint]

    subscript(joint: Joint) -> JointPoint? { joints[joint] }

    static let skeletonEdges: [(Joint, Joint)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    /// Limb segments drawn as bone art; the torso is covered by ribcage +
    /// pelvis pieces instead of edges.
    static let limbSegments: [(Joint, Joint)] = [
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    /// Minimum confidence to *draw* a joint (keep the skeleton alive) and to
    /// *count reps* (be forgiving so real reps aren't missed).
    static let minConfidence: Float = 0.2

    /// Higher bar to make a *form judgment* (depth, lean, valgus, bar drift).
    /// A joint tracked below this is too uncertain to accuse someone of bad
    /// form — better to stay silent than flag a fault that isn't there. This
    /// is the single biggest guard against false-positive "your form is bad"
    /// calls, which are what earn an app one-star reviews.
    static let formConfidence: Float = 0.5

    private func isConfident(_ joints: Joint..., threshold: Float) -> Bool {
        joints.allSatisfy { (self.joints[$0]?.confidence ?? 0) >= threshold }
    }

    func midpoint(of a: Joint, _ b: Joint) -> CGPoint? {
        guard let pa = joints[a], let pb = joints[b],
              pa.confidence >= Self.minConfidence, pb.confidence >= Self.minConfidence else { return nil }
        return CGPoint(x: (pa.location.x + pb.location.x) / 2,
                       y: (pa.location.y + pb.location.y) / 2)
    }

    private func bestSingle(of a: Joint, _ b: Joint) -> CGPoint? {
        [joints[a], joints[b]]
            .compactMap { $0 }
            .filter { $0.confidence >= Self.minConfidence }
            .max { $0.confidence < $1.confidence }?
            .location
    }

    var hipCenter: CGPoint? {
        if let root = joints[.root], root.confidence >= Self.minConfidence { return root.location }
        return midpoint(of: .leftHip, .rightHip) ?? bestSingle(of: .leftHip, .rightHip)
    }

    var shoulderCenter: CGPoint? {
        midpoint(of: .leftShoulder, .rightShoulder) ?? bestSingle(of: .leftShoulder, .rightShoulder)
    }

    var kneeCenter: CGPoint? {
        midpoint(of: .leftKnee, .rightKnee) ?? bestSingle(of: .leftKnee, .rightKnee)
    }

    /// Side view: the clearly-seen (camera-side) knee. The far knee is often
    /// occluded and misplaced, and a midpoint would drag depth judgment off.
    /// Requires form-grade confidence — a shaky knee must not drive a depth call.
    var mostConfidentKneeY: CGFloat? {
        [joints[.leftKnee], joints[.rightKnee]]
            .compactMap { $0 }
            .filter { $0.confidence >= Self.formConfidence }
            .max { $0.confidence < $1.confidence }?
            .location.y
    }

    var ankleCenter: CGPoint? {
        midpoint(of: .leftAnkle, .rightAnkle) ?? bestSingle(of: .leftAnkle, .rightAnkle)
    }

    /// Wrist midpoint — the barbell proxy for deadlift bar-path tracking.
    var wristCenter: CGPoint? {
        midpoint(of: .leftWrist, .rightWrist) ?? bestSingle(of: .leftWrist, .rightWrist)
    }

    /// Head-to-ankle vertical extent, for size-normalizing distances.
    var bodySpan: CGFloat? {
        let headY = [joints[.nose], joints[.neck]]
            .compactMap { $0 }
            .filter { $0.confidence >= Self.minConfidence }
            .map(\.location.y)
            .min()
        let ankleY = [joints[.leftAnkle], joints[.rightAnkle]]
            .compactMap { $0 }
            .filter { $0.confidence >= Self.minConfidence }
            .map(\.location.y)
            .max()
        guard let headY, let ankleY, ankleY - headY > 0.15 else { return nil }
        return ankleY - headY
    }

    /// Torso angle from vertical in degrees (0 = perfectly upright).
    /// Corrects for the image aspect ratio since coordinates are normalized per-axis.
    /// Only computed when hips and shoulders are confidently tracked — a lean
    /// accusation on guessed joints is worse than no accusation.
    var torsoLeanDegrees: Double? {
        guard let hip = hipCenter, let shoulder = shoulderCenter,
              (isConfident(.leftHip, .rightHip, threshold: Self.formConfidence)
               || isConfident(.root, threshold: Self.formConfidence)),
              isConfident(.leftShoulder, .rightShoulder, threshold: Self.formConfidence)
                || (joints[.leftShoulder]?.confidence ?? 0) >= Self.formConfidence
                || (joints[.rightShoulder]?.confidence ?? 0) >= Self.formConfidence
        else { return nil }
        let dx = Double(shoulder.x - hip.x) * Double(imageAspect)
        let dy = Double(hip.y - shoulder.y) // positive when shoulders are above hips
        guard dy > 0.001 else { return 90 }
        return atan2(abs(dx), dy) * 180 / .pi
    }

    /// Inner angle at a joint in degrees, aspect-corrected.
    func angleDegrees(at vertex: Joint, from a: Joint, to b: Joint) -> Double? {
        guard let v = joints[vertex], let pa = joints[a], let pb = joints[b],
              min(v.confidence, pa.confidence, pb.confidence) >= Self.minConfidence else { return nil }
        let ax = Double(pa.location.x - v.location.x) * Double(imageAspect)
        let ay = Double(pa.location.y - v.location.y)
        let bx = Double(pb.location.x - v.location.x) * Double(imageAspect)
        let by = Double(pb.location.y - v.location.y)
        let magA = (ax * ax + ay * ay).squareRoot()
        let magB = (bx * bx + by * by).squareRoot()
        guard magA > 0.001, magB > 0.001 else { return nil }
        let cosine = max(-1, min(1, (ax * bx + ay * by) / (magA * magB)))
        return acos(cosine) * 180 / .pi
    }

    /// Largest elbow extension (180° = straight arm) from whichever arm is
    /// visible — bench lockout detection.
    var maxElbowExtensionDegrees: Double? {
        [angleDegrees(at: .leftElbow, from: .leftShoulder, to: .leftWrist),
         angleDegrees(at: .rightElbow, from: .rightShoulder, to: .rightWrist)]
            .compactMap { $0 }
            .max()
    }

    /// Front view: knee separation as a fraction of ankle separation.
    /// Below ~1 the knees are tracking inside the ankles — valgus territory.
    /// A ratio of x-distances, so the image aspect cancels out.
    var kneeSeparationRatio: CGFloat? {
        guard let lk = joints[.leftKnee], let rk = joints[.rightKnee],
              let la = joints[.leftAnkle], let ra = joints[.rightAnkle],
              min(lk.confidence, rk.confidence, la.confidence, ra.confidence) >= Self.formConfidence
        else { return nil }
        let ankleWidth = abs(la.location.x - ra.location.x)
        guard ankleWidth > 0.02 else { return nil } // feet together / side view — ratio is meaningless
        return abs(lk.location.x - rk.location.x) / ankleWidth
    }

    /// Front view: signed lateral hip shift as a fraction of stance width.
    /// 0 = centered between the ankles; ±0.5 = hip directly over one ankle.
    var lateralShiftRatio: CGFloat? {
        guard let hip = hipCenter,
              let la = joints[.leftAnkle], let ra = joints[.rightAnkle],
              min(la.confidence, ra.confidence) >= Self.formConfidence,
              isConfident(.leftHip, .rightHip, threshold: Self.formConfidence)
                || isConfident(.root, threshold: Self.formConfidence) else { return nil }
        let ankleWidth = abs(la.location.x - ra.location.x)
        guard ankleWidth > 0.02 else { return nil }
        let ankleMidX = (la.location.x + ra.location.x) / 2
        return (hip.x - ankleMidX) / ankleWidth
    }
}
