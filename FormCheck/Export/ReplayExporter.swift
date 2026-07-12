import AVFoundation
import CoreImage
import UIKit

enum ReplayExportError: LocalizedError {
    case noVideoTrack
    case readerFailed
    case writerFailed

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "The set recording has no video track."
        case .readerFailed: return "Couldn't read the set recording."
        case .writerFailed: return "Couldn't write the replay video."
        }
    }
}

/// Re-renders one rep from the set recording as a slow-motion clip with the
/// skeleton, score card, and watermark burned in. Fully offline — this export
/// is the shareable asset and the app's growth loop.
enum ReplayExporter {
    /// `xray: true` renders on pure black — just the skeleton, bar path, and
    /// card. Anonymous PR posting: share the lift without being in the video.
    static func export(recording: SessionRecording,
                       clip: RepClip,
                       xray: Bool = false,
                       slowMotionFactor: Double = 2.0) async throws -> URL {
        let asset = AVURLAsset(url: recording.url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ReplayExportError.noVideoTrack
        }
        let naturalSize = try await track.load(.naturalSize)
        let width = Int(naturalSize.width)
        let height = Int(naturalSize.height)

        let reader = try AVAssetReader(asset: asset)
        let clipStart = CMTime(seconds: clip.start, preferredTimescale: 600)
        let clipDuration = CMTime(seconds: max(clip.end - clip.start, 0.1), preferredTimescale: 600)
        reader.timeRange = CMTimeRange(start: clipStart, duration: clipDuration)
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        guard reader.canAdd(readerOutput) else { throw ReplayExportError.readerFailed }
        reader.add(readerOutput)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FormCheck-rep\(clip.score.repIndex)-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw ReplayExportError.writerFailed }
        writer.add(input)

        guard writer.startWriting() else { throw ReplayExportError.writerFailed }
        writer.startSession(atSourceTime: .zero)
        guard reader.startReading() else { throw ReplayExportError.readerFailed }

        let overlay = OverlayRenderer(size: CGSize(width: width, height: height),
                                      score: clip.score, streak: clip.streak)
        let trail = makeTrail(from: recording.poses, exercise: clip.score.exercise)
        let ciContext = CIContext()
        let blackFrame = CIImage(color: .black)
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        var poseIndex = 0

        while let sample = readerOutput.copyNextSampleBuffer() {
            guard let source = CMSampleBufferGetImageBuffer(sample) else { continue }

            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else { throw ReplayExportError.writerFailed }
            var destination: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &destination)
            guard let dest = destination else { throw ReplayExportError.writerFailed }

            ciContext.render(xray ? blackFrame : CIImage(cvPixelBuffer: source), to: dest)

            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            let pose = nearestPose(in: recording.poses, at: pts.seconds, from: &poseIndex)
            // Dust puff over the last stretch of the clip — the lockout moment.
            let puffWindow = 0.35
            let puffStart = clip.end - puffWindow
            let puffProgress: CGFloat? = pts.seconds >= puffStart
                ? CGFloat(min(1, (pts.seconds - puffStart) / puffWindow))
                : nil
            overlay.draw(on: dest, pose: pose, puffProgress: puffProgress,
                         trail: trail, at: pts.seconds)

            let outputTime = CMTimeMultiplyByFloat64(CMTimeSubtract(pts, clipStart),
                                                     multiplier: Float64(slowMotionFactor))
            guard adaptor.append(dest, withPresentationTime: outputTime) else {
                throw ReplayExportError.writerFailed
            }
        }

        if reader.status == .failed { throw ReplayExportError.readerFailed }
        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else { throw ReplayExportError.writerFailed }
        return outputURL
    }

    private static func makeTrail(from poses: [PoseFrame], exercise: Exercise) -> [TrailSample] {
        var result: [TrailSample] = []
        for pose in poses {
            guard let point = BarTrail.barPoint(in: pose, exercise: exercise) else { continue }
            let speed = BarTrail.speed(from: result.last, to: point, at: pose.timestamp,
                                       aspect: pose.imageAspect, bodySpan: pose.bodySpan)
            result.append(TrailSample(point: point, time: pose.timestamp, speed: speed))
        }
        return result
    }

    /// Poses and video frames share the recording timeline; walk a cursor forward
    /// instead of searching, since frames arrive in order.
    private static func nearestPose(in poses: [PoseFrame],
                                    at time: TimeInterval,
                                    from index: inout Int) -> PoseFrame? {
        while index + 1 < poses.count, poses[index + 1].timestamp <= time {
            index += 1
        }
        guard index < poses.count, abs(poses[index].timestamp - time) < 0.15 else { return nil }
        return poses[index]
    }
}

/// Draws the cartoon skeleton (vector skull/ribcage/pelvis/bones with a glow)
/// and the pre-rendered score card onto BGRA pixel buffers — matching the
/// live overlay.
private final class OverlayRenderer {
    private let size: CGSize
    private let glowColor: CGColor
    private let cardImage: CGImage?
    private let skullImage: CGImage?
    private let boneImage: CGImage?
    private let ribcageImage: CGImage?
    private let pelvisImage: CGImage?
    private let mittImage: CGImage?
    private let shoeImage: CGImage?
    private let puffImage: CGImage?
    private let flexImage: CGImage?
    private let exercise: Exercise
    private let isCleanRep: Bool

    init(size: CGSize, score: RepScore, streak: Int) {
        self.size = size
        exercise = score.exercise
        isCleanRep = score.faults.isEmpty
        let base: UIColor = score.faults.isEmpty ? .systemGreen : .systemRed
        glowColor = base.withAlphaComponent(0.85).cgColor
        cardImage = Self.makeCard(size: size, score: score, streak: streak)
        // Vector assets rasterized once at generous sizes; drawn scaled down.
        skullImage = Self.partImage(score.faults.isEmpty ? "skel-skull" : "skel-skull-dead", height: 420)
        boneImage = Self.partImage("skel-bone", height: 480)
        ribcageImage = Self.partImage("skel-ribcage", height: 460)
        pelvisImage = Self.partImage("skel-pelvis", height: 380)
        mittImage = Self.emojiImage("🧤", size: 140)
        shoeImage = Self.emojiImage("👟", size: 140)
        puffImage = Self.emojiImage("💨", size: 140)
        flexImage = Self.emojiImage("💪", size: 140)
    }

    /// Renders a vector asset to a bitmap at the given height, preserving
    /// crispness (UIImage.draw uses the vector data at target size).
    private static func partImage(_ name: String, height: CGFloat) -> CGImage? {
        guard let ui = UIImage(named: name), ui.size.height > 0 else { return nil }
        let target = CGSize(width: height * ui.size.width / ui.size.height, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            ui.draw(in: CGRect(origin: .zero, size: target))
        }
        return image.cgImage
    }

    func draw(on buffer: CVPixelBuffer, pose: PoseFrame?, puffProgress: CGFloat?,
              trail: [TrailSample], at now: TimeInterval) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(
                data: base,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return }

        drawTrail(context, trail: trail, at: now)

        if let pose {
            var points: [Joint: CGPoint] = [:]
            for (joint, jointPoint) in pose.joints where jointPoint.confidence > PoseFrame.minConfidence {
                points[joint] = point(jointPoint.location)
            }

            // Skeleton pieces with the status glow.
            context.setShadow(offset: .zero, blur: 14, color: glowColor)

            if let boneImage {
                for (a, b) in PoseFrame.limbSegments {
                    guard let pa = points[a], let pb = points[b] else { continue }
                    let angle = atan2(pb.y - pa.y, pb.x - pa.x)
                    drawRotated(context, boneImage,
                                center: mid(pa, pb),
                                rotation: angle - .pi / 2, // vertical asset → along segment (CG, y-up)
                                height: hypot(pb.x - pa.x, pb.y - pa.y) * 1.12)
                }
            }

            let neckP = points[.neck] ?? points[.leftShoulder].flatMap { l in points[.rightShoulder].map { mid(l, $0) } }
            let rootP = points[.root] ?? points[.leftHip].flatMap { l in points[.rightHip].map { mid(l, $0) } }

            if let pelvisImage, let lh = points[.leftHip], let rh = points[.rightHip] {
                let width = max(hypot(rh.x - lh.x, rh.y - lh.y) * 2.2, 40)
                drawRotated(context, pelvisImage,
                            center: mid(lh, rh),
                            rotation: atan2(rh.y - lh.y, rh.x - lh.x),
                            height: width * CGFloat(pelvisImage.height) / CGFloat(pelvisImage.width))
            }

            if let ribcageImage, let neckP, let rootP {
                let torsoAngle = atan2(neckP.y - rootP.y, neckP.x - rootP.x)
                let center = CGPoint(x: rootP.x + (neckP.x - rootP.x) * 0.55,
                                     y: rootP.y + (neckP.y - rootP.y) * 0.55)
                drawRotated(context, ribcageImage,
                            center: center,
                            rotation: torsoAngle - .pi / 2,
                            height: hypot(neckP.x - rootP.x, neckP.y - rootP.y) * 1.05)
            }

            // Accessories without the glow.
            context.setShadow(offset: .zero, blur: 0, color: nil)
            drawShoes(context, points: points)
            drawMitts(context, points: points)

            if let skullImage, let neckP {
                context.setShadow(offset: .zero, blur: 14, color: glowColor)
                let noseP = points[.nose]
                let axis = noseP.map { CGPoint(x: $0.x - neckP.x, y: $0.y - neckP.y) }
                    ?? CGPoint(x: 0, y: 1) // no nose: upright above the neck (CG up = +y)
                let axisLength = max(hypot(axis.x, axis.y), 1)
                let height: CGFloat = noseP != nil ? axisLength * 2.9 : 110
                let center = CGPoint(x: (noseP ?? neckP).x + axis.x * 0.35,
                                     y: (noseP ?? neckP).y + axis.y * 0.35)
                drawRotated(context, skullImage,
                            center: center,
                            rotation: atan2(axis.y, axis.x) - .pi / 2,
                            height: height)
                context.setShadow(offset: .zero, blur: 0, color: nil)
            }

            if let puffProgress {
                drawPuffs(context, points: points, progress: puffProgress)
                if isCleanRep {
                    drawFlexes(context, points: points, progress: puffProgress)
                }
            }
        }

        if let cardImage {
            context.draw(cardImage, in: CGRect(origin: .zero, size: size))
        }
    }

    private func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Velocity-colored bar path up to the current frame time.
    private func drawTrail(_ context: CGContext, trail: [TrailSample], at now: TimeInterval) {
        guard trail.count >= 2 else { return }
        context.setLineCap(.round)
        context.setLineWidth(10)
        for i in 1..<trail.count {
            let a = trail[i - 1]
            let b = trail[i]
            guard b.time <= now, now - b.time <= BarTrail.window,
                  b.time - a.time < 0.3 else { continue }
            let alpha = (1 - (now - b.time) / BarTrail.window) * 0.9
            let (r, g, bl) = BarTrail.rgb(forSpeed: b.speed)
            context.setStrokeColor(CGColor(red: r, green: g, blue: bl, alpha: alpha))
            context.move(to: point(a.point))
            context.addLine(to: point(b.point))
            context.strokePath()
        }
    }

    private func drawRotated(_ context: CGContext, _ image: CGImage,
                             center: CGPoint, rotation: CGFloat, height: CGFloat) {
        let width = height * CGFloat(image.width) / CGFloat(image.height)
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: rotation)
        context.draw(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        context.restoreGState()
    }

    /// Lockout dust puffs: grow, drift outward and up, fade — at the feet,
    /// or at the bar (wrists) for bench.
    private func drawPuffs(_ context: CGContext, points: [Joint: CGPoint], progress: CGFloat) {
        guard let puffImage else { return }
        let joints: [(Joint, CGFloat)] = exercise.tracksWrists
            ? [(.leftWrist, -1), (.rightWrist, 1)]
            : [(.leftAnkle, -1), (.rightAnkle, 1)]
        let puffSize: CGFloat = 60 * (0.5 + progress * 1.2)

        context.saveGState()
        context.setAlpha(1 - progress)
        for (joint, direction) in joints {
            guard let point = points[joint] else { continue }
            let rect = CGRect(x: point.x - puffSize / 2 + direction * 40 * progress,
                              y: point.y - puffSize / 2 + 20 * progress,
                              width: puffSize, height: puffSize)
            context.draw(puffImage, in: rect)
        }
        context.restoreGState()
    }

    /// Clean-rep celebration: 💪 popping off both shoulders at lockout.
    private func drawFlexes(_ context: CGContext, points: [Joint: CGPoint], progress: CGFloat) {
        guard let flexImage else { return }
        let flexSize: CGFloat = 72 * (0.5 + progress * 1.1)

        context.saveGState()
        context.setAlpha(1 - progress)
        for (joint, direction) in [(Joint.leftShoulder, CGFloat(-1)), (.rightShoulder, 1)] {
            guard let point = points[joint] else { continue }
            // CG origin is bottom-left, so rising means +y here.
            let rect = CGRect(x: point.x - flexSize / 2 + direction * 46 * progress,
                              y: point.y - flexSize / 2 + 55 * progress,
                              width: flexSize, height: flexSize)
            if direction < 0 {
                // Mirror the left-side flex so both biceps face outward.
                context.saveGState()
                context.translateBy(x: rect.midX, y: 0)
                context.scaleBy(x: -1, y: 1)
                context.translateBy(x: -rect.midX, y: 0)
                context.draw(flexImage, in: rect)
                context.restoreGState()
            } else {
                context.draw(flexImage, in: rect)
            }
        }
        context.restoreGState()
    }

    /// Sneakers on the ankles, sized from the shin.
    private func drawShoes(_ context: CGContext, points: [Joint: CGPoint]) {
        guard let shoeImage else { return }
        for (ankle, knee) in [(Joint.leftAnkle, Joint.leftKnee), (.rightAnkle, .rightKnee)] {
            guard let anklePoint = points[ankle] else { continue }
            let shoeSize: CGFloat
            if let kneePoint = points[knee] {
                shoeSize = min(108, max(36, hypot(anklePoint.x - kneePoint.x,
                                                  anklePoint.y - kneePoint.y) * 0.5))
            } else {
                shoeSize = 52
            }
            // CG origin is bottom-left, so nudging the shoe toward the floor
            // means subtracting from y here (the live view adds instead).
            let rect = CGRect(x: anklePoint.x - shoeSize / 2,
                              y: anklePoint.y - shoeSize / 2 - shoeSize * 0.2,
                              width: shoeSize, height: shoeSize)
            context.draw(shoeImage, in: rect)
        }
    }

    /// Boxing-glove mitts on the wrists, sized from the forearm.
    private func drawMitts(_ context: CGContext, points: [Joint: CGPoint]) {
        guard let mittImage else { return }
        for (wrist, elbow) in [(Joint.leftWrist, Joint.leftElbow), (.rightWrist, .rightElbow)] {
            guard let wristPoint = points[wrist] else { continue }
            let mittSize: CGFloat
            if let elbowPoint = points[elbow] {
                mittSize = min(100, max(32, hypot(wristPoint.x - elbowPoint.x,
                                                  wristPoint.y - elbowPoint.y) * 0.55))
            } else {
                mittSize = 48
            }
            let rect = CGRect(x: wristPoint.x - mittSize / 2, y: wristPoint.y - mittSize / 2,
                              width: mittSize, height: mittSize)
            context.draw(mittImage, in: rect)
        }
    }

    private static func emojiImage(_ emoji: String, size: CGFloat) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let image = renderer.image { _ in
            let attributed = NSAttributedString(string: emoji, attributes: [
                .font: UIFont.systemFont(ofSize: size * 0.82),
            ])
            let textSize = attributed.size()
            attributed.draw(at: CGPoint(x: (size - textSize.width) / 2,
                                        y: (size - textSize.height) / 2))
        }
        return image.cgImage
    }

    /// Normalized top-left coords → CG (bottom-left origin) pixel coords.
    private func point(_ normalized: CGPoint) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: size.height - normalized.y * size.height)
    }

    private static func makeCard(size: CGSize, score: RepScore, streak: Int) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        var lines: [NSAttributedString] = [
            NSAttributedString(string: "REP \(score.repIndex) — GRADE \(score.grade)", attributes: [
                .font: UIFont.systemFont(ofSize: 44, weight: .black),
                .foregroundColor: UIColor.white,
            ]),
            NSAttributedString(string: "Score \(score.score)", attributes: [
                .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            ]),
        ]
        if score.faults.isEmpty {
            lines.append(NSAttributedString(string: "Clean rep ✓", attributes: [
                .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                .foregroundColor: UIColor.systemGreen,
            ]))
            if streak >= 3 {
                lines.append(NSAttributedString(string: "🔥 \(streak) clean in a row", attributes: [
                    .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                    .foregroundColor: UIColor.systemOrange,
                ]))
            }
        } else {
            for fault in score.faults {
                lines.append(NSAttributedString(string: "⚠︎ \(fault.rawValue)", attributes: [
                    .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                    .foregroundColor: UIColor.systemOrange,
                ]))
            }
        }

        let image = renderer.image { _ in
            let lineSpacing: CGFloat = 10
            let padding: CGFloat = 26
            let sizes = lines.map { $0.size() }
            let contentHeight = sizes.reduce(0) { $0 + $1.height } + CGFloat(max(lines.count - 1, 0)) * lineSpacing
            let cardWidth = min(sizes.map(\.width).max()! + padding * 2, size.width - 40)
            let cardRect = CGRect(x: (size.width - cardWidth) / 2, y: 70,
                                  width: cardWidth, height: contentHeight + padding * 2)

            UIColor.black.withAlphaComponent(0.55).setFill()
            UIBezierPath(roundedRect: cardRect, cornerRadius: 26).fill()

            var y = cardRect.minY + padding
            for (line, lineSize) in zip(lines, sizes) {
                line.draw(at: CGPoint(x: (size.width - lineSize.width) / 2, y: y))
                y += lineSize.height + lineSpacing
            }

            let watermark = NSAttributedString(string: "FORMCHECK", attributes: [
                .font: UIFont.systemFont(ofSize: 36, weight: .black),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .kern: 6,
            ])
            let markSize = watermark.size()
            watermark.draw(at: CGPoint(x: (size.width - markSize.width) / 2,
                                       y: size.height - markSize.height - 70))
        }
        return image.cgImage
    }
}
