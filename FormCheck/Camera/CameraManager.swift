import AVFoundation
import Combine
import CoreVideo
import Foundation
import UIKit

/// Owns the capture session and runs pose detection on each frame.
/// Buffers are rotated upright at the connection level so Vision, the
/// preview layer, and the overlay all share one coordinate space —
/// in whichever orientation the phone is propped.
final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var permissionDenied = false
    /// Rotation applied to buffers and preview. 90 = portrait phone.
    /// Updated while setting up; frozen once a set is underway.
    @Published private(set) var videoRotationAngle: CGFloat = 90

    /// Called on the main queue with each pose frame: raw (lowest latency,
    /// some jitter) and smoothed (One Euro filtered, for display and scoring).
    var onPose: ((_ raw: PoseFrame, _ smoothed: PoseFrame) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "formcheck.camera.session")
    private let frameQueue = DispatchQueue(label: "formcheck.camera.frames")
    private let poseProvider: PoseProvider = VisionPoseProvider()
    private let smoother = PoseSmoother()
    private var isConfigured = false
    private var configuredSide: CameraSide? // touched on sessionQueue only
    private var recorder: SessionRecorder? // touched on frameQueue only
    /// Knows the correct upright angle for the *current* camera — front and
    /// back sensors need different rotations in landscape.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    override init() {
        super.init()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    func start(side: CameraSide) {
        updateRotationAngle()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configureAndRun(side: side) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.sessionQueue.async { self.configureAndRun(side: side) }
                } else {
                    DispatchQueue.main.async { self.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func resetSmoothing() {
        frameQueue.async {
            self.smoother.reset()
            self.poseProvider.reset()
        }
    }

    /// Re-reads the device orientation and re-aims the capture rotation.
    /// Call from the main thread, and only between sets or during placement —
    /// changing mid-set would invalidate calibration and the recording.
    func updateRotationAngle() {
        // The coordinator is camera-aware; the manual mapping is only the
        // fallback for the frames before the session is configured.
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture
            ?? Self.currentRotationAngle()
        guard angle != videoRotationAngle else { return }
        videoRotationAngle = angle
        sessionQueue.async {
            guard let connection = self.videoOutput.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }

    private static func currentRotationAngle() -> CGFloat {
        // Device orientation first (fresher during a rotation), interface
        // orientation as the fallback when the device is flat or unknown.
        switch UIDevice.current.orientation {
        case .portrait: return 90
        case .landscapeLeft: return 0
        case .landscapeRight: return 180
        default:
            let interface = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .interfaceOrientation
            switch interface {
            case .landscapeRight: return 0
            case .landscapeLeft: return 180
            default: return 90
            }
        }
    }

    /// Begins writing the set to a temp file; actual writing starts with the first frame.
    func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("formcheck-set-\(UUID().uuidString).mov")
        frameQueue.async { self.recorder = SessionRecorder(url: url) }
    }

    /// Finalizes the recording; completion is called on the main queue.
    func stopRecording(_ completion: @escaping (SessionRecording?) -> Void) {
        frameQueue.async {
            guard let recorder = self.recorder else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.recorder = nil
            recorder.finish { recording in
                DispatchQueue.main.async { completion(recording) }
            }
        }
    }

    private func configureAndRun(side: CameraSide) {
        if !isConfigured || configuredSide != side {
            session.beginConfiguration()
            // 720p is plenty for pose detection and keeps Vision fast.
            session.sessionPreset = .hd1280x720

            // Swap the input when the user changes camera between sets.
            session.inputs.forEach { session.removeInput($0) }

            let position: AVCaptureDevice.Position = side == .front ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            if !session.outputs.contains(videoOutput) {
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                ]
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
                guard session.canAddOutput(videoOutput) else {
                    session.commitConfiguration()
                    return
                }
                session.addOutput(videoOutput)
            }

            // Swapping the input rebuilds the connection — reapply settings.
            // Front buffers are mirrored so they match the mirrored preview;
            // Vision, the overlay, and the recording then all agree.
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = side == .front
                }
                let angle = videoRotationAngle
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }

            session.commitConfiguration()
            isConfigured = true
            configuredSide = side

            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            DispatchQueue.main.async {
                self.rotationCoordinator = coordinator
                self.updateRotationAngle()
            }
        }
        if !session.isRunning { session.startRunning() }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        recorder?.append(sampleBuffer)
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard let raw = poseProvider.detectPose(in: pixelBuffer, timestamp: timestamp) else { return }
        let smoothed = smoother.smooth(raw)
        recorder?.appendPose(smoothed)
        DispatchQueue.main.async { self.onPose?(raw, smoothed) }
    }
}
