// Trims transparent edges and pads to square: swift tools/trim.swift in.png out.png size
import AppKit
let a = CommandLine.arguments
let img = NSImage(contentsOfFile: a[1])!
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
for y in stride(from: 0, to: rep.pixelsHigh, by: 2) { for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
  if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } } }
let w = maxX - minX, h = maxY - minY, side = CGFloat(max(w, h)) * 1.04
let S = CGFloat(Int(a[3])!)
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
let scale = S / side
let cg = rep.cgImage!
let src = CGRect(x: minX, y: minY, width: w, height: h)
let crop = cg.cropping(to: src)!
let dw = CGFloat(w) * scale, dh = CGFloat(h) * scale
NSGraphicsContext.current!.cgContext.draw(crop, in: CGRect(x: (S - dw) / 2, y: 0, width: dw, height: dh))
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
