import CoreVideo
import Foundation

/// Abstraction over the pose-estimation backend so Vision can be swapped for
/// MediaPipe BlazePose later (Android port, or when heel/toe landmarks are needed).
protocol PoseProvider {
    /// Expects an upright (portrait-oriented) pixel buffer.
    func detectPose(in pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> PoseFrame?
    /// Drop cross-frame tracking state (person lock-on) between sets.
    func reset()
}
