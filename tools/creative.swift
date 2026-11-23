// swift tools/creative.swift → AppStore/creative/header.png (3840x1646) + search.png (3840x2560)
// Key content stays inside Apple's safe areas (top-left origin):
//   header 1646x661 @ (1097,493)   search 2168x1030 @ (836,765)
import AppKit

let ink = NSColor(red: 0.035, green: 0.043, blue: 0.035, alpha: 1)
let ink2 = NSColor(red: 0.06, green: 0.10, blue: 0.05, alpha: 1)
let lime = NSColor(red: 0.616, green: 1.0, blue: 0.235, alpha: 1)
let red = NSColor(red: 1.0, green: 0.27, blue: 0.27, alpha: 1)

func font(_ s: CGFloat, _ w: NSFont.Weight) -> NSFont {
    let f = NSFont.systemFont(ofSize: s, weight: w)
    return NSFont(descriptor: f.fontDescriptor.withDesign(.rounded)!, size: s) ?? f
}
func img(_ p: String) -> NSImage { NSImage(contentsOfFile: p)! }
func glow(_ c: NSColor, _ r: NSRect, _ a: CGFloat) {
    // soft radial falloff (no visible edge)
    let ctx = NSGraphicsContext.current!.cgContext
    let cols = [c.withAlphaComponent(a).cgColor, c.withAlphaComponent(a * 0.35).cgColor, c.withAlphaComponent(0).cgColor] as CFArray
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 0.45, 1])!
    let center = CGPoint(x: r.midX, y: r.midY)
    ctx.saveGState(); ctx.translateBy(x: center.x, y: center.y); ctx.scaleBy(x: 1, y: r.height / r.width)
    ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: r.width / 2, options: [])
    ctx.restoreGState()
}
func shadowed(_ color: NSColor = .black, _ blur: CGFloat = 70, _ draw: () -> Void) {
    let s = NSShadow(); s.shadowColor = color; s.shadowBlurRadius = blur; s.shadowOffset = NSSize(width: 0, height: -20); s.set()
    draw(); NSShadow().set()
}
/// Skeleton "motion lines": a stylised squat stick figure drawn in glowing strokes.
func skeletonLines(_ origin: NSPoint, _ s: CGFloat, _ c: NSColor) {
    let pts: [NSPoint] = [ // head, neck, hip, knee, ankle, shoulder->elbow->wrist
        NSPoint(x: 0.10, y: 1.00), NSPoint(x: 0.18, y: 0.86), NSPoint(x: 0.62, y: 0.42),
        NSPoint(x: 0.30, y: 0.36), NSPoint(x: 0.40, y: 0.0)]
    let p = NSBezierPath(); p.lineCapStyle = .round; p.lineJoinStyle = .round
    p.move(to: NSPoint(x: origin.x + pts[1].x * s, y: origin.y + pts[1].y * s))
    for q in pts[2...] { p.line(to: NSPoint(x: origin.x + q.x * s, y: origin.y + q.y * s)) }
    for (m, a) in [(6.0, 0.08), (2.6, 0.22), (1.0, 1.0)] as [(CGFloat, CGFloat)] {
        c.withAlphaComponent(a).setStroke(); p.lineWidth = 10 * m; p.stroke()
    }
    for q in pts.dropFirst() {
        let r = NSRect(x: origin.x + q.x * s - 16, y: origin.y + q.y * s - 16, width: 32, height: 32)
        NSColor.white.setFill(); NSBezierPath(ovalIn: r).fill()
    }
}
func background(_ W: CGFloat, _ H: CGFloat) {
    NSGradient(colors: [ink2, ink])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
    glow(lime, NSRect(x: W * 0.15, y: -H * 0.35, width: W * 0.7, height: H * 1.6), 0.30)
    // faint grid like a calibration screen
    NSColor.white.withAlphaComponent(0.03).setStroke()
    let g = NSBezierPath(); g.lineWidth = 2
    stride(from: 0, through: W, by: 120).forEach { g.move(to: NSPoint(x: $0, y: 0)); g.line(to: NSPoint(x: $0, y: H)) }
    stride(from: 0, through: H, by: 120).forEach { g.move(to: NSPoint(x: 0, y: $0)); g.line(to: NSPoint(x: W, y: $0)) }
    g.stroke()
}
func phone(_ path: String, _ r: NSRect, tilt: CGFloat = 0) {
    let im = img(path)
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform(); t.translateX(by: r.midX, yBy: r.midY); t.rotate(byDegrees: tilt); t.translateX(by: -r.midX, yBy: -r.midY); t.concat()
    let rad = r.width * 0.11
    let body = NSBezierPath(roundedRect: r.insetBy(dx: -16, dy: -16), xRadius: rad + 16, yRadius: rad + 16)
    shadowed(.black, 110) { NSColor(white: 0.07, alpha: 1).setFill(); body.fill() }
    lime.withAlphaComponent(0.45).setStroke(); body.lineWidth = 5; body.stroke()
    let screen = NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad)
    screen.addClip(); im.draw(in: r)
    NSGraphicsContext.restoreGraphicsState()
}
func pill(_ text: String, _ center: NSPoint, _ size: CGFloat, fill: NSColor, fg: NSColor) {
    let a = NSAttributedString(string: text, attributes: [.font: font(size, .black), .foregroundColor: fg])
    let s = a.size(); let r = NSRect(x: center.x - s.width / 2 - size * 0.6, y: center.y - s.height / 2 - size * 0.3,
                                    width: s.width + size * 1.2, height: s.height + size * 0.6)
    shadowed(fill.withAlphaComponent(0.7), 50) { fill.setFill(); NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2).fill() }
    a.draw(at: NSPoint(x: center.x - s.width / 2, y: center.y - s.height / 2))
}
func render(_ W: CGFloat, _ H: CGFloat, _ out: String, _ body: () -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    background(W, H); body()
    NSGraphicsContext.restoreGraphicsState()
    // flatten to opaque RGB PNG (Apple rejects alpha)
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: W, height: H))
    try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
}

try? FileManager.default.createDirectory(atPath: "AppStore/creative", withIntermediateDirectories: true)
let A = "FormCheck/Assets.xcassets"
let squat = img("\(A)/bones-squat.imageset/bones-squat.png")
let win = img("\(A)/bones-win.imageset/bones-win.png")
let wave = img("\(A)/bones-wave.imageset/bones-wave.png")

// HEADER 3840x1646 — Bones front and centre, the live coaching screens flanking him.
// Safe area in AppKit coords: x 1097…2743, y 492…1153.
render(3840, 1646, "AppStore/creative/header.png") {
    phone("AppStore/shots/live-squat.png", NSRect(x: 280, y: -380, width: 760, height: 1651), tilt: 8)
    phone("AppStore/shots/live-squat-warn.png", NSRect(x: 2800, y: -380, width: 760, height: 1651), tilt: -8)
    glow(lime, NSRect(x: 1300, y: 200, width: 1240, height: 1240), 0.45)
    shadowed(lime.withAlphaComponent(0.55), 90) { squat.draw(in: NSRect(x: 1920 - 620, y: 330, width: 1240, height: 1240)) }
    pill("DEPTH ✓", NSPoint(x: 1340, y: 1030), 92, fill: lime, fg: .black)
    pill("CHEST UP", NSPoint(x: 2520, y: 760), 72, fill: red, fg: .white)
    // bottom fade so Apple's title overlay stays readable
    NSGradient(colors: [ink, ink.withAlphaComponent(0)])!.draw(in: NSRect(x: 0, y: 0, width: 3840, height: 560), angle: 90)
}

// SEARCH RESULTS 3840x2560 — headline + Bones + two live screens.
// Safe area in AppKit coords: x 836…3004, y 765…1795.
render(3840, 2560, "AppStore/creative/search.png") {
    let tag = NSAttributedString(string: "FORMCHECK", attributes: [.font: font(66, .black), .foregroundColor: lime, .kern: 18])
    tag.draw(at: NSPoint(x: 900, y: 1690))
    let p = NSMutableParagraphStyle(); p.maximumLineHeight = 170
    let head = NSMutableAttributedString(string: "Your AI coach\nsees every rep.",
                                         attributes: [.font: font(158, .black), .foregroundColor: NSColor.white, .paragraphStyle: p])
    head.addAttribute(.foregroundColor, value: lime, range: (head.string as NSString).range(of: "every rep."))
    head.draw(with: NSRect(x: 900, y: 1290, width: 1500, height: 390), options: [.usesLineFragmentOrigin])
    ("Live skeleton · Voice cues · A–F grade" as NSString).draw(with: NSRect(x: 900, y: 1180, width: 1400, height: 90),
        options: [.usesLineFragmentOrigin],
        attributes: [.font: NSFont.systemFont(ofSize: 60, weight: .bold), .foregroundColor: NSColor.white.withAlphaComponent(0.75)])
    pill("Try a free set today", NSPoint(x: 1260, y: 1010), 58, fill: lime, fg: .black)
    shadowed(lime.withAlphaComponent(0.5), 70) { win.draw(in: NSRect(x: 1560, y: 330, width: 700, height: 700)) }
    phone("AppStore/shots/live-squat-warn.png", NSRect(x: 2230, y: 300, width: 560, height: 1217), tilt: 5)
    phone("AppStore/shots/live-squat.png", NSRect(x: 2640, y: 520, width: 600, height: 1304), tilt: -4)
    _ = wave
}
print("ok")
