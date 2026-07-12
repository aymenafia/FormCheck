import CoreVideo
import Foundation
import Vision

final class VisionPoseProvider: PoseProvider {
    private let request = VNDetectHumanBodyPoseRequest()

    /// Where the lifter's hip was last frame — the anchor that keeps the
    /// detector locked on one person when others walk through the frame.
    private var lastHip: CGPoint?

    private static let jointMap: [VNHumanBodyPoseObservation.JointName: Joint] = [
        .nose: .nose, .neck: .neck,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .root: .root, .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle,
    ]

    func reset() {
        lastHip = nil
    }

    func detectPose(in pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> PoseFrame? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observations = request.results, !observations.isEmpty else { return nil }

        let candidates = observations.compactMap(Self.joints(from:))
        guard let chosen = pickLifter(from: candidates) else { return nil }
        lastHip = Self.hip(of: chosen)

        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        return PoseFrame(timestamp: timestamp, imageAspect: width / height, joints: chosen)
    }

    /// Prefer whoever is where the lifter was last frame; among those (or all,
    /// if the track was lost), take the largest person — bystanders in the
    /// background are small.
    private func pickLifter(from candidates: [[Joint: JointPoint]]) -> [Joint: JointPoint]? {
        guard !candidates.isEmpty else { return nil }
        if let lastHip {
            let near = candidates.filter { candidate in
                guard let hip = Self.hip(of: candidate) else { return false }
                return abs(hip.x - lastHip.x) + abs(hip.y - lastHip.y) < 0.25
            }
            if let best = near.max(by: { Self.extent(of: $0) < Self.extent(of: $1) }) {
                return best
            }
        }
        return candidates.max { Self.extent(of: $0) < Self.extent(of: $1) }
    }

    private static func joints(from observation: VNHumanBodyPoseObservation) -> [Joint: JointPoint]? {
        guard let recognized = try? observation.recognizedPoints(.all) else { return nil }
        var joints: [Joint: JointPoint] = [:]
        for (vnJoint, joint) in jointMap {
            guard let point = recognized[vnJoint], point.confidence > 0.1 else { continue }
            // Vision uses a lower-left origin; flip to top-left.
            joints[joint] = JointPoint(
                location: CGPoint(x: point.location.x, y: 1 - point.location.y),
                confidence: point.confidence
            )
        }
        return joints.count >= 4 ? joints : nil
    }

    private static func hip(of joints: [Joint: JointPoint]) -> CGPoint? {
        (joints[.root] ?? joints[.leftHip] ?? joints[.rightHip])?.location
    }

    private static func extent(of joints: [Joint: JointPoint]) -> CGFloat {
        let ys = joints.values.map(\.location.y)
        guard let top = ys.min(), let bottom = ys.max() else { return 0 }
        return bottom - top
    }
}
