import AVFoundation
import Foundation

struct SessionRecording {
    let url: URL
    /// Capture-clock time (seconds) of the first recorded frame — the recording's t = 0.
    /// Used to rebase RepMetrics timestamps into the recording timeline.
    let sourceStartTime: TimeInterval
    /// Smoothed pose frames with timestamps rebased to the recording timeline,
    /// so replays can re-draw the skeleton offline.
    let poses: [PoseFrame]
}

/// Writes the live set to disk (H.264) while capture runs and collects pose frames.
/// Cheap enough to run alongside Vision: the hardware encoder does the work.
/// All methods must be called on the camera frame queue.
final class SessionRecorder {
    private let url: URL
    private let writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var startPTS: CMTime?
    private var poses: [PoseFrame] = []

    init(url: URL) {
        self.url = url
        try? FileManager.default.removeItem(at: url)
        writer = try? AVAssetWriter(outputURL: url, fileType: .mov)
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        guard let writer, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Lazy setup on the first frame so dimensions come from the actual buffers.
        if startPTS == nil {
            let newInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: CVPixelBufferGetWidth(pixelBuffer),
                AVVideoHeightKey: CVPixelBufferGetHeight(pixelBuffer),
            ])
            newInput.expectsMediaDataInRealTime = true
            guard writer.canAdd(newInput) else { return }
            writer.add(newInput)
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: pts)
            input = newInput
            startPTS = pts
        }

        if let input, input.isReadyForMoreMediaData, writer.status == .writing {
            input.append(sampleBuffer)
        }
    }

    func appendPose(_ frame: PoseFrame) {
        guard let startPTS else { return }
        var rebased = frame
        rebased.timestamp = frame.timestamp - startPTS.seconds
        poses.append(rebased)
    }

    func finish(completion: @escaping (SessionRecording?) -> Void) {
        guard let writer, writer.status == .writing, let input, let startPTS else {
            completion(nil)
            return
        }
        input.markAsFinished()
        let result = SessionRecording(url: url, sourceStartTime: startPTS.seconds, poses: poses)
        writer.finishWriting {
            completion(writer.status == .completed ? result : nil)
        }
    }
}
