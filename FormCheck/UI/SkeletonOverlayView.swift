import SwiftUI

/// Draws over the camera preview, back to front: the velocity-colored bar
/// path, the translucent ghost of the best rep, and the live cartoon skeleton
/// (vector skull/ribcage/pelvis/bones) with a status glow and live-fault
/// joint rings. Mapping mirrors the preview layer's `.resizeAspectFill`.
struct SkeletonOverlayView: View {
    let pose: PoseFrame?
    let faulted: Bool
    /// Joints to ring in red while a live fault is happening.
    let highlight: [Joint]
    let ghost: PoseFrame?
    let trail: [TrailSample]

    var body: some View {
        Canvas { context, size in
            drawTrail(context, size: size)

            if let ghost {
                var layer = context
                layer.opacity = 0.35
                drawSkeleton(ghost, in: layer, size: size, deadSkull: false)
            }

            if let pose {
                var layer = context
                layer.addFilter(.shadow(color: (faulted ? Color.red : .green).opacity(0.8), radius: 6))
                drawSkeleton(pose, in: layer, size: size, deadSkull: faulted)
                drawHighlights(context, pose: pose, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Bar path

    private func drawTrail(_ context: GraphicsContext, size: CGSize) {
        guard trail.count >= 2, let newest = trail.last?.time,
              let aspect = (pose ?? ghost)?.imageAspect else { return }
        for i in 1..<trail.count {
            let a = trail[i - 1]
            let b = trail[i]
            guard b.time - a.time < 0.3 else { continue } // tracking gap — don't connect
            let alpha = max(0, 1 - (newest - b.time) / BarTrail.window) * 0.9
            let (r, g, bl) = BarTrail.rgb(forSpeed: b.speed)
            var path = Path()
            path.move(to: OverlayMapping.viewPoint(a.point, imageAspect: aspect, in: size))
            path.addLine(to: OverlayMapping.viewPoint(b.point, imageAspect: aspect, in: size))
            context.stroke(path,
                           with: .color(Color(red: r, green: g, blue: bl).opacity(alpha)),
                           style: StrokeStyle(lineWidth: 8, lineCap: .round))
        }
    }

    // MARK: - Skeleton

    private func drawSkeleton(_ pose: PoseFrame, in layer: GraphicsContext,
                              size: CGSize, deadSkull: Bool) {
        var points: [Joint: CGPoint] = [:]
        for (joint, point) in pose.joints where point.confidence > PoseFrame.minConfidence {
            points[joint] = OverlayMapping.viewPoint(point.location, imageAspect: pose.imageAspect, in: size)
        }

        // Limb bones, behind the torso pieces.
        let bone = layer.resolve(Image("skel-bone"))
        for (a, b) in PoseFrame.limbSegments {
            guard let pa = points[a], let pb = points[b] else { continue }
            let angle = atan2(pb.y - pa.y, pb.x - pa.x)
            draw(bone, in: layer,
                 center: mid(pa, pb),
                 rotation: angle + .pi / 2, // vertical asset → along the segment (y-down)
                 height: hypot(pb.x - pa.x, pb.y - pa.y) * 1.12)
        }

        // Torso anchors, with fallbacks when Vision drops a joint.
        let neckP = points[.neck] ?? points[.leftShoulder].flatMap { l in points[.rightShoulder].map { mid(l, $0) } }
        let rootP = points[.root] ?? points[.leftHip].flatMap { l in points[.rightHip].map { mid(l, $0) } }

        if let lh = points[.leftHip], let rh = points[.rightHip] {
            let pelvis = layer.resolve(Image("skel-pelvis"))
            let width = max(hypot(rh.x - lh.x, rh.y - lh.y) * 2.2, 30)
            draw(pelvis, in: layer,
                 center: mid(lh, rh),
                 rotation: atan2(rh.y - lh.y, rh.x - lh.x),
                 height: width * pelvis.size.height / pelvis.size.width)
        }

        if let neckP, let rootP {
            let ribcage = layer.resolve(Image("skel-ribcage"))
            let torsoAngle = atan2(neckP.y - rootP.y, neckP.x - rootP.x)
            let center = CGPoint(x: rootP.x + (neckP.x - rootP.x) * 0.55,
                                 y: rootP.y + (neckP.y - rootP.y) * 0.55)
            draw(ribcage, in: layer,
                 center: center,
                 rotation: torsoAngle + .pi / 2,
                 height: hypot(neckP.x - rootP.x, neckP.y - rootP.y) * 1.05)
        }

        if let neckP {
            let skull = layer.resolve(Image(deadSkull ? "skel-skull-dead" : "skel-skull"))
            let noseP = points[.nose]
            // With no nose (back turned), sit the skull upright above the neck.
            let axis = noseP.map { CGPoint(x: $0.x - neckP.x, y: $0.y - neckP.y) }
                ?? CGPoint(x: 0, y: -1)
            let axisLength = max(hypot(axis.x, axis.y), 1)
            let height = noseP != nil ? axisLength * 2.9 : 60
            let center = CGPoint(x: (noseP ?? neckP).x + axis.x * 0.35,
                                 y: (noseP ?? neckP).y + axis.y * 0.35)
            draw(skull, in: layer,
                 center: center,
                 rotation: atan2(axis.y, axis.x) + .pi / 2,
                 height: height)
        }
    }

    // MARK: - Live-fault rings

    private func drawHighlights(_ context: GraphicsContext, pose: PoseFrame, size: CGSize) {
        guard !highlight.isEmpty else { return }
        var alert = context
        alert.addFilter(.shadow(color: .red.opacity(0.9), radius: 8))
        for joint in highlight {
            guard let point = pose.joints[joint],
                  point.confidence > PoseFrame.minConfidence else { continue }
            let p = OverlayMapping.viewPoint(point.location, imageAspect: pose.imageAspect, in: size)
            let outer = CGRect(x: p.x - 30, y: p.y - 30, width: 60, height: 60)
            alert.stroke(Path(ellipseIn: outer), with: .color(.red),
                         style: StrokeStyle(lineWidth: 5))
            alert.stroke(Path(ellipseIn: outer.insetBy(dx: 13, dy: 13)),
                         with: .color(.red.opacity(0.7)),
                         style: StrokeStyle(lineWidth: 3))
        }
    }

    // MARK: - Helpers

    private func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func draw(_ image: GraphicsContext.ResolvedImage,
                      in context: GraphicsContext,
                      center: CGPoint, rotation: CGFloat, height: CGFloat) {
        let width = height * image.size.width / image.size.height
        var local = context
        local.translateBy(x: center.x, y: center.y)
        local.rotate(by: .radians(rotation))
        local.draw(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
    }
}
