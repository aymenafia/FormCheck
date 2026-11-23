// App Store screenshot composer for FormCheck (1320x2868, 6.9").
//   swift tools/shots.swift live <photo> <out.png> <reps> <mode: depth|warn> <warnText>
//      -> renders the photo as the app's live screen: Vision body pose + FormCheck-style skeleton + HUD
//   swift tools/shots.swift frame <screen.png> <out.png> "<line1>" "<line2>" "<accentWord>" [mascot.png]
//      -> marketing frame: headline + device + optional mascot
import AppKit
import Vision

let W = 1320, H = 2868
let lime = NSColor(red: 0.616, green: 1.0, blue: 0.235, alpha: 1)
let ink = NSColor(red: 0.035, green: 0.043, blue: 0.035, alpha: 1)
let args = CommandLine.arguments

func canvas(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSGraphicsContext.current!.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
func save(_ rep: NSBitmapImageRep, _ path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
func cg(_ path: String) -> CGImage {
    NSImage(contentsOfFile: path)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded) { return NSFont(descriptor: d, size: size) ?? base }
    return base
}
func drawText(_ s: String, _ f: NSFont, _ color: NSColor, center: CGPoint) -> CGSize {
    let a = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: color])
    let sz = a.size()
    a.draw(at: CGPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2))
    return sz
}
func pill(_ ctx: CGContext, _ rect: CGRect, _ color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil))
    ctx.fillPath()
}

// MARK: live screen
func live(photo: String, out: String, reps: String, mode: String, warn: String) {
    let img = cg(photo)
    // aspect-fill into phone screen
    let scale = max(Double(W) / Double(img.width), Double(H) / Double(img.height))
    let dw = Double(img.width) * scale, dh = Double(img.height) * scale
    let dx = (Double(W) - dw) / 2, dy = (Double(H) - dh) / 2

    let req = VNDetectHumanBodyPoseRequest()
    try! VNImageRequestHandler(cgImage: img).perform([req])
    let obs = req.results?.first
    var pts: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    if let o = obs, let all = try? o.recognizedPoints(.all) {
        for (k, p) in all where p.confidence > 0.25 {
            pts[k] = CGPoint(x: dx + Double(p.location.x) * dw, y: dy + Double(p.location.y) * dh)
        }
    }
    print("joints detected:", pts.count)
    let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .nose), (.neck, .leftShoulder), (.neck, .rightShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist), (.neck, .root), (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle), (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)]
    let warnMode = mode == "warn"
    let boneColor = warnMode ? NSColor.systemRed : NSColor.systemGreen

    let rep = canvas(W, H) { ctx in
        ctx.draw(img, in: CGRect(x: dx, y: dy, width: dw, height: dh))
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.18).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        // skeleton with glow
        ctx.setShadow(offset: .zero, blur: 22, color: boneColor.withAlphaComponent(0.9).cgColor)
        ctx.setStrokeColor(boneColor.cgColor); ctx.setLineWidth(20); ctx.setLineCap(.round)
        for (a, b) in bones { if let p = pts[a], let q = pts[b] { ctx.move(to: p); ctx.addLine(to: q) } }
        ctx.strokePath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        for (_, p) in pts {
            ctx.setFillColor(NSColor.white.cgColor); ctx.fillEllipse(in: CGRect(x: p.x - 15, y: p.y - 15, width: 30, height: 30))
            ctx.setFillColor(boneColor.cgColor); ctx.fillEllipse(in: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18))
        }
        // red alert rings on the faulted joint (hip/shoulder area)
        if warnMode, let p = pts[.neck] ?? pts[.rightShoulder] ?? pts[.leftShoulder] {
            ctx.setStrokeColor(NSColor.systemRed.cgColor); ctx.setLineWidth(12)
            ctx.strokeEllipse(in: CGRect(x: p.x - 80, y: p.y - 80, width: 160, height: 160))
            ctx.setLineWidth(7); ctx.strokeEllipse(in: CGRect(x: p.x - 54, y: p.y - 54, width: 108, height: 108))
            // red edge glow
            ctx.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.55).cgColor); ctx.setLineWidth(40)
            ctx.addPath(CGPath(roundedRect: CGRect(x: 10, y: 10, width: W - 20, height: H - 20), cornerWidth: 150, cornerHeight: 150, transform: nil)); ctx.strokePath()
        }
        // top: phase pill + End Set
        pill(ctx, CGRect(x: 60, y: H - 330, width: 330, height: 110), NSColor.black.withAlphaComponent(0.45))
        _ = drawText(warnMode ? "Rising" : (warn.isEmpty ? "Bottom" : "Lockout"), font(46, .semibold), .white, center: CGPoint(x: 225, y: H - 275))
        pill(ctx, CGRect(x: W - 370, y: H - 330, width: 310, height: 110), NSColor.systemRed.withAlphaComponent(0.85))
        _ = drawText("End Set", font(46, .semibold), .white, center: CGPoint(x: W - 215, y: H - 275))
        if warnMode {
            let f = font(64, .black)
            let a = NSAttributedString(string: "⚠︎  " + warn.uppercased(), attributes: [.font: f])
            let w = a.size().width + 120
            pill(ctx, CGRect(x: (Double(W) - w) / 2, y: Double(H) - 520, width: w, height: 150), NSColor.systemRed.withAlphaComponent(0.93))
            _ = drawText("⚠︎  " + warn.uppercased(), f, .white, center: CGPoint(x: W / 2, y: H - 445))
        } else {
            pill(ctx, CGRect(x: W / 2 - 300, y: H - 560, width: 600, height: 170), lime)
            _ = drawText(warn.isEmpty ? "DEPTH ✓" : warn, font(96, .black), .black, center: CGPoint(x: W / 2, y: H - 475))
        }
        // bottom: rep counter
        _ = drawText(reps, font(300, .black), .white, center: CGPoint(x: W / 2, y: 470))
        _ = drawText("REPS", font(48, .bold), NSColor.white.withAlphaComponent(0.75), center: CGPoint(x: W / 2, y: 290))
        if !warnMode {
            pill(ctx, CGRect(x: W / 2 - 290, y: 140, width: 580, height: 110), NSColor.orange.withAlphaComponent(0.9))
            _ = drawText("🔥 \(reps) in a row", font(56, .black), .white, center: CGPoint(x: W / 2, y: 195))
        }
    }
    save(rep, out)
}

// MARK: marketing frame
func frame(screen: String, out: String, l1: String, l2: String, accent: String, mascot: String?) {
    let scr = cg(screen)
    let rep = canvas(W, H) { ctx in
        ctx.setFillColor(ink.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        let space = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorsSpace: space, colors: [lime.withAlphaComponent(0.45).cgColor, lime.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: W / 2, y: H - 200), startRadius: 0, endCenter: CGPoint(x: W / 2, y: H - 200), endRadius: 1500, options: [])
        // headline
        let f = font(118, .black)
        for (i, line) in [l1, l2].enumerated() {
            let a = NSMutableAttributedString(string: line, attributes: [.font: f, .foregroundColor: NSColor.white])
            if let r = line.range(of: accent) { a.addAttribute(.foregroundColor, value: lime, range: NSRange(r, in: line)) }
            let sz = a.size()
            a.draw(at: CGPoint(x: (Double(W) - sz.width) / 2, y: Double(H) - 290 - Double(i) * 140))
        }
        // device
        let dwid = 1000.0, dhei = dwid * Double(scr.height) / Double(scr.width)
        let rect = CGRect(x: (Double(W) - dwid) / 2, y: Double(H) - 470 - dhei, width: dwid, height: dhei)
        let bezel = rect.insetBy(dx: -26, dy: -26)
        ctx.setShadow(offset: CGSize(width: 0, height: -30), blur: 80, color: NSColor.black.withAlphaComponent(0.7).cgColor)
        ctx.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor)
        ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: 150, cornerHeight: 150, transform: nil)); ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setStrokeColor(lime.withAlphaComponent(0.35).cgColor); ctx.setLineWidth(5)
        ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: 150, cornerHeight: 150, transform: nil)); ctx.strokePath()
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 125, cornerHeight: 125, transform: nil)); ctx.clip()
        ctx.draw(scr, in: rect)
        ctx.restoreGState()
        if let m = mascot {
            let mi = cg(m); let s = 560.0
            ctx.setShadow(offset: .zero, blur: 60, color: lime.withAlphaComponent(0.5).cgColor)
            ctx.draw(mi, in: CGRect(x: Double(W) - s + 40, y: 40, width: s, height: s))
        }
    }
    save(rep, out)
}

switch args[1] {
case "live": live(photo: args[2], out: args[3], reps: args[4], mode: args[5], warn: args.count > 6 ? args[6] : "")
case "frame": frame(screen: args[2], out: args[3], l1: args[4], l2: args[5], accent: args[6], mascot: args.count > 7 ? args[7] : nil)
default: print("usage")
}
