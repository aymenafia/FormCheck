// swift tools/split.swift strip.png outPrefix  — splits a horizontal strip of 1024px squares
import AppKit
let a = CommandLine.arguments
let img = NSImage(contentsOfFile: a[1])!
let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let n = cg.width / cg.height
for i in 0..<n {
    let c = cg.cropping(to: CGRect(x: i * cg.height, y: 0, width: cg.height, height: cg.height))!
    let rep = NSBitmapImageRep(cgImage: c)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(a[2])\(i).png"))
}
print("split", n)
