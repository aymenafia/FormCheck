import CoreGraphics

/// One correction at a time, in priority order — the user fixes the biggest
/// problem first instead of reading a checklist.
enum PlacementIssue: Equatable {
    case noBody
    case tooFar
    case tooClose
    case offCenter
    case turnSideways
    case faceCamera
    case lieDown

    var message: String {
        switch self {
        case .noBody: return "Step into the frame"
        case .tooFar: return "Move closer to the camera"
        case .tooClose: return "Step back from the camera"
        case .offCenter: return "Move toward the center"
        case .turnSideways: return "Turn side-on to the camera"
        case .faceCamera: return "Turn to face the camera"
        case .lieDown: return "Lie back on the bench"
        }
    }

    var systemImage: String {
        switch self {
        case .noBody: return "person.fill.viewfinder"
        case .tooFar: return "arrow.down.left.and.arrow.up.right"
        case .tooClose: return "arrow.up.left.and.arrow.down.right"
        case .offCenter: return "arrow.left.and.right"
        case .turnSideways: return "rotate.3d"
        case .faceCamera: return "person.fill"
        case .lieDown: return "bed.double.fill"
        }
    }
}

/// Validates camera placement from live pose frames before a set begins,
/// so bad placement (the #1 cause of bad scoring) never becomes the user's default.
struct PlacementChecker {
    /// Head-to-ankle span as a fraction of frame height: the "right distance" band.
    var spanRange: ClosedRange<CGFloat> = 0.5...0.85
    /// Where the hip center must sit horizontally.
    var centerBand: ClosedRange<CGFloat> = 0.28...0.72
    /// Shoulder width relative to body span — wide means facing the camera,
    /// narrow means side-on. Bands are lenient so they don't nag.
    var minFrontShoulderRatio: CGFloat = 0.12
    var maxSideShoulderRatio: CGFloat = 0.20
    /// Bench (lying): head-to-ankle horizontal extent as a fraction of frame width.
    var lyingSpanRange: ClosedRange<CGFloat> = 0.55...0.95

    func check(_ frame: PoseFrame, exercise: Exercise, mode: ViewMode) -> PlacementIssue? {
        exercise.tracksWrists ? checkLying(frame) : checkStanding(frame, mode: mode)
    }

    /// Bench: the body is horizontal, so distance is judged by width coverage
    /// and orientation by which axis the body extends along.
    private func checkLying(_ frame: PoseFrame) -> PlacementIssue? {
        guard let head = headPoint(of: frame),
              let ankle = anklePoint(of: frame),
              let hip = frame.hipCenter else { return .noBody }

        let verticalSpan = abs(ankle.y - head.y)
        let horizontalSpan = abs(ankle.x - head.x)
        // Compare in the same units: x-distances shrink by the aspect ratio.
        if verticalSpan > horizontalSpan * frame.imageAspect { return .lieDown }

        if horizontalSpan < lyingSpanRange.lowerBound { return .tooFar }
        if horizontalSpan > lyingSpanRange.upperBound { return .tooClose }
        if !centerBand.contains(hip.x) { return .offCenter }
        return nil
    }

    private func checkStanding(_ frame: PoseFrame, mode: ViewMode) -> PlacementIssue? {
        guard let headY = headY(of: frame),
              let ankleY = lowestAnkleY(of: frame),
              let hip = frame.hipCenter else { return .noBody }

        let span = ankleY - headY
        guard span > 0.15 else { return .noBody }
        if span < spanRange.lowerBound { return .tooFar }
        if span > spanRange.upperBound { return .tooClose }
        if !centerBand.contains(hip.x) { return .offCenter }

        if let ls = frame.joints[.leftShoulder], let rs = frame.joints[.rightShoulder],
           min(ls.confidence, rs.confidence) >= PoseFrame.minConfidence {
            let shoulderRatio = abs(ls.location.x - rs.location.x) * frame.imageAspect / span
            switch mode {
            case .front where shoulderRatio < minFrontShoulderRatio:
                return .faceCamera
            case .side where shoulderRatio > maxSideShoulderRatio:
                return .turnSideways
            default:
                break
            }
        }
        return nil
    }

    private func headY(of frame: PoseFrame) -> CGFloat? {
        [frame.joints[.nose], frame.joints[.neck]]
            .compactMap { $0 }
            .filter { $0.confidence >= PoseFrame.minConfidence }
            .map(\.location.y)
            .min()
    }

    private func lowestAnkleY(of frame: PoseFrame) -> CGFloat? {
        [frame.joints[.leftAnkle], frame.joints[.rightAnkle]]
            .compactMap { $0 }
            .filter { $0.confidence >= PoseFrame.minConfidence }
            .map(\.location.y)
            .max()
    }

    private func headPoint(of frame: PoseFrame) -> CGPoint? {
        bestPoint(of: [frame.joints[.nose], frame.joints[.neck]])
    }

    private func anklePoint(of frame: PoseFrame) -> CGPoint? {
        bestPoint(of: [frame.joints[.leftAnkle], frame.joints[.rightAnkle]])
    }

    private func bestPoint(of candidates: [JointPoint?]) -> CGPoint? {
        candidates
            .compactMap { $0 }
            .filter { $0.confidence >= PoseFrame.minConfidence }
            .max { $0.confidence < $1.confidence }?
            .location
    }
}
