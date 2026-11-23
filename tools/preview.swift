// composite cutouts on dark bg into one preview: swift preview.swift out.png in1 in2 ...
import AppKit
let a = CommandLine.arguments
let files = Array(a.dropFirst(2)); let s = 300
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: s*files.count, pixelsHigh: s, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: s*files.count, height: s).fill()
for (i,f) in files.enumerated() { NSImage(contentsOfFile: f)!.draw(in: NSRect(x: i*s, y: 0, width: s, height: s)) }
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[1]))
